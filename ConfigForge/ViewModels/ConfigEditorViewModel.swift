import SwiftUI
import Combine
import Foundation
import Yams // 导入 Yams 用于 YAML 解析

/// 配置编辑器视图模型，处理配置文件编辑状态和操作
@MainActor
class ConfigEditorViewModel: ObservableObject {
    // MARK: - 发布属性
    
    /// 当前正在编辑的配置文件
    @Published var configFile: KubeConfigFile?
    
    /// 编辑器内容
    @Published var editorContent: String = ""
    
    /// 是否处于编辑模式
    @Published var isEditing: Bool = false
    
    /// 是否有未保存的更改
    @Published var hasUnsavedChanges: Bool = false
    
    /// 错误消息
    @Published var errorMessage: String?
    
    /// 历史记录堆栈 - 用于撤销/重做
    private var undoStack: [String] = []
    private var redoStack: [String] = []
    
    /// 最大撤销历史记录数
    private let maxUndoHistory: Int = 50
    
    /// 编辑器验证状态
    @Published var validationState: ValidationState = .notValidated
    
    // MARK: - 依赖项
    
    private let kubeConfigFileManager = KubeConfigFileManager()
    private let messageHandler: MessageHandler
    
    /// 验证定时器
    private var validationTimer: Timer?
    
    // MARK: - 初始化
    
    init(messageHandler: MessageHandler = MessageHandler()) {
        self.messageHandler = messageHandler
    }
    
    // MARK: - 编辑器操作
    
    /// 加载配置文件内容
    /// - Parameter configFile: 要加载的配置文件
    func loadConfigFile(_ configFile: KubeConfigFile) {
        Task {
            do {
                // 使用正确的方法读取文件内容
                let content = try String(contentsOf: configFile.filePath, encoding: .utf8)
                await MainActor.run {
                    self.configFile = configFile
                    self.editorContent = content
                    self.isEditing = false
                    self.hasUnsavedChanges = false
                    self.clearHistory()
                    self.validateContent()
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "无法加载配置文件: \(error.localizedDescription)"
                    self.messageHandler.show("无法加载配置文件", type: .error)
                }
            }
        }
    }
    
    /// 开始编辑
    func startEditing() {
        if !isEditing {
            // 保存当前内容到撤销堆栈
            pushToUndoStack(editorContent)
            isEditing = true
        }
    }
    
    /// 停止编辑
    func stopEditing() {
        isEditing = false
    }
    
    /// 更新编辑器内容
    /// - Parameter newContent: 新内容
    func updateContent(_ newContent: String) {
        // 仅在编辑模式下更新内容
        if isEditing {
            let oldContent = editorContent
            editorContent = newContent
            hasUnsavedChanges = true
            
            // 如果内容变化较大，保存到撤销堆栈
            if abs(oldContent.count - newContent.count) > 10 {
                pushToUndoStack(oldContent)
            }
            
            // 设置验证计时器
            scheduleValidation()
        }
    }
    
    /// 保存当前编辑内容
    func saveChanges() {
        guard let configFile = configFile, hasUnsavedChanges else { return }
        
        // 先验证内容
        if case .invalid(_) = validationState {
            messageHandler.show("配置包含错误，无法保存", type: .error)
            return
        }
        
        Task {
            do {
                // 保存文件
                try editorContent.write(to: configFile.filePath, atomically: true, encoding: .utf8)
                
                // 验证保存的内容
                let validationResult = await validateYamlContent(editorContent)
                
                switch validationResult {
                case .success:
                    // 更新配置文件对象的状态
                    var updatedFile = configFile
                    updatedFile.updateYamlContent(editorContent)
                    updatedFile.status = .valid
                    
                    // 更新视图模型状态
                    await MainActor.run {
                        self.configFile = updatedFile
                        self.hasUnsavedChanges = false
                        self.clearRedoStack()
                        self.messageHandler.show("配置已保存", type: .success)
                    }
                    
                    // 如果是活动配置，通知更改
                    if configFile.fileType == .active {
                        EventManager.shared.notifyActiveConfigChanged(editorContent)
                    }
                    
                case .failure(let error):
                    // 更新配置文件对象的状态
                    var updatedFile = configFile
                    updatedFile.updateYamlContent(editorContent)
                    updatedFile.markAsInvalid(error.localizedDescription)
                    
                    await MainActor.run {
                        self.configFile = updatedFile
                        self.messageHandler.show("配置已保存，但验证未通过：\(error.localizedDescription)", type: .error)
                        self.hasUnsavedChanges = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "保存配置失败: \(error.localizedDescription)"
                    self.messageHandler.show("保存配置失败", type: .error)
                }
            }
        }
    }
    
    /// 放弃更改
    func discardChanges() {
        if let configFile = configFile {
            loadConfigFile(configFile)
        }
    }
    
    // MARK: - 撤销/重做功能
    
    /// 将内容添加到撤销堆栈
    private func pushToUndoStack(_ content: String) {
        undoStack.append(content)
        
        // 限制堆栈大小
        if undoStack.count > maxUndoHistory {
            undoStack.removeFirst()
        }
    }
    
    /// 撤销上一次操作
    func undo() {
        guard !undoStack.isEmpty && isEditing else { return }
        
        // 将当前内容推入重做堆栈
        redoStack.append(editorContent)
        
        // 从撤销堆栈中弹出内容
        let previousContent = undoStack.removeLast()
        editorContent = previousContent
        
        // 如果撤销堆栈为空，表示回到初始状态
        hasUnsavedChanges = !undoStack.isEmpty
        
        validateContent()
    }
    
    /// 重做上一次撤销的操作
    func redo() {
        guard !redoStack.isEmpty && isEditing else { return }
        
        // 将当前内容推入撤销堆栈
        pushToUndoStack(editorContent)
        
        // 从重做堆栈中弹出内容
        let nextContent = redoStack.removeLast()
        editorContent = nextContent
        hasUnsavedChanges = true
        
        validateContent()
    }
    
    /// 清除撤销/重做历史
    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    /// 清除重做堆栈
    private func clearRedoStack() {
        redoStack.removeAll()
    }
    
    // MARK: - 验证功能
    
    /// 验证状态枚举
    enum ValidationState: Equatable {
        case notValidated
        case validating
        case valid
        case invalid(String)
    }
    
    /// 安排延迟验证
    private func scheduleValidation() {
        // 取消现有计时器
        validationTimer?.invalidate()
        
        // 将状态设为正在验证
        validationState = .validating
        
        // 创建新计时器，延迟0.8秒验证
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.validateContent()
            }
        }
    }
    
    /// 验证编辑器内容
    func validateContent() {
        guard !editorContent.isEmpty else {
            validationState = .invalid("配置不能为空")
            return
        }
        
        // 使用 Yams 验证 YAML 内容
        Task {
            let validationResult = await validateYamlContent(editorContent)
            
            await MainActor.run {
                switch validationResult {
                case .success:
                    self.validationState = .valid
                case .failure(let error):
                    let errorMessage = "验证失败: \(error.localizedDescription)"
                    self.validationState = .invalid(errorMessage)
                }
            }
        }
    }
    
    /// 验证 YAML 内容
    private func validateYamlContent(_ content: String) async -> Result<Void, ConfigForgeError> {
        do {
            // 使用 Yams 解析 YAML
            guard let yaml = try Yams.load(yaml: content) as? [String: Any] else {
                return .failure(.validation("YAML 格式错误：无法解析为字典"))
            }
            
            // 基本结构验证 - 检查必要的字段
            guard let clusters = yaml["clusters"] as? [[String: Any]], !clusters.isEmpty else {
                return .failure(.validation("配置缺少集群定义"))
            }
            
            guard let contexts = yaml["contexts"] as? [[String: Any]], !contexts.isEmpty else {
                return .failure(.validation("配置缺少上下文定义"))
            }
            
            guard let users = yaml["users"] as? [[String: Any]], !users.isEmpty else {
                return .failure(.validation("配置缺少用户定义"))
            }
            
            // 检查当前上下文是否有效
            if let currentContext = yaml["current-context"] as? String {
                let contextExists = contexts.contains { context in
                    if let contextName = (context["name"] as? String) {
                        return contextName == currentContext
                    }
                    return false
                }
                
                if !contextExists {
                    return .failure(.validation("当前上下文 '\(currentContext)' 未在配置中定义"))
                }
            }
            
            // 验证上下文引用的集群和用户是否存在
            for context in contexts {
                guard let name = context["name"] as? String,
                      let contextDict = context["context"] as? [String: Any],
                      let clusterName = contextDict["cluster"] as? String,
                      let userName = contextDict["user"] as? String else {
                    return .failure(.validation("上下文定义格式错误"))
                }
                
                // 检查集群是否存在
                let clusterExists = clusters.contains { cluster in
                    if let clusterNameInList = cluster["name"] as? String {
                        return clusterNameInList == clusterName
                    }
                    return false
                }
                
                if !clusterExists {
                    return .failure(.validation("上下文 '\(name)' 引用了未定义的集群 '\(clusterName)'"))
                }
                
                // 检查用户是否存在
                let userExists = users.contains { user in
                    if let userNameInList = user["name"] as? String {
                        return userNameInList == userName
                    }
                    return false
                }
                
                if !userExists {
                    return .failure(.validation("上下文 '\(name)' 引用了未定义的用户 '\(userName)'"))
                }
            }
            
            return .success(())
        } catch {
            return .failure(.validation("YAML 解析错误: \(error.localizedDescription)"))
        }
    }
    
    /// 配置文件是否有效
    var isConfigValid: Bool {
        switch validationState {
        case .valid:
            return true
        default:
            return false
        }
    }
    
    // MARK: - 计算属性
    
    /// 编辑器标题
    var editorTitle: String {
        configFile?.displayName ?? "无选定配置"
    }
    
    /// 配置文件状态
    var configStatus: KubeConfigFileStatus {
        configFile?.status ?? .unknown
    }
    
    /// 是否可以撤销
    var canUndo: Bool {
        isEditing && !undoStack.isEmpty
    }
    
    /// 是否可以重做
    var canRedo: Bool {
        isEditing && !redoStack.isEmpty
    }
} 
