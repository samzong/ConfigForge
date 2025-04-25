//
//  SSHConfigViewModel.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI
import Combine // Import Combine for AnyCancellable if needed later
import Foundation
import AppKit // 导入 AppKit 用于 NSAlert 和 NSTextField

// MARK: - Enums for State Management

// Type of configuration being viewed/edited
enum ConfigType: String, CaseIterable, Identifiable {
    case ssh = "SSH"
    case kubernetes = "Kubernetes"
    var id: String { self.rawValue }
}

@MainActor
class MainViewModel: ObservableObject {
    @Published var selectedConfigurationType: ConfigType = .ssh // Top level selector
    @Published var searchText: String = ""
    @Published var configSearchText: String = "" // Search text for config files
    @Published var selectedEntry: (any Identifiable)? // Can hold SSH entries
    @Published var selectedConfigFile: KubeConfigFile? // For selected Kubernetes config file
    @Published var isEditing: Bool = false
    @Published var errorMessage: String?
    @Published var appMessage: AppMessage?
    @Published var isLoading: Bool = false
    @Published var isLoadingConfigFiles: Bool = false // Loading indicator for config files
    
    @Published var sshEntries: [SSHConfigEntry] = [] // For SSH config
    @Published var kubeConfig: KubeConfig? // Current active Kubernetes config
    
    // 配置文件列表
    @Published var configFiles: [KubeConfigFile] = []
    @Published var selectedConfigFileContent: String = ""
    
    private let asyncUtility = AsyncUtility()
    private let messageHandler = MessageHandler()
    private let sshFileManager = SSHConfigFileManager()
    private let kubeConfigFileManager = KubeConfigFileManager()
    let sshParser = SSHConfigParser()
    
    // 计算属性：过滤后的条目列表 (仅 SSH 条目)
    var displayedEntries: [any Identifiable] {
        if selectedConfigurationType == .ssh {
            if searchText.isEmpty {
                return sshEntries.sorted { $0.host < $1.host }
            } else {
                return sshEntries.filter { 
                    $0.host.localizedCaseInsensitiveContains(searchText) 
                }.sorted { $0.host < $1.host }
            }
        }
        return []
    }
    
    // 计算属性：过滤后的配置文件列表
    var displayedConfigFiles: [KubeConfigFile] {
        if configSearchText.isEmpty {
            return configFiles
        } else {
            return configFiles.filter { 
                $0.fileName.localizedCaseInsensitiveContains(configSearchText) ||
                $0.displayName.localizedCaseInsensitiveContains(configSearchText)
            }
        }
    }
    
    // MARK: - UI Thread Safety
    
    /// Ensures UI updates are performed on the main thread
    /// - Parameter action: The UI update action to perform
    @MainActor
    func updateUIState(action: @escaping () -> Void) {
        action()
    }
    
    // MARK: - Message Posting Helper
    
    /// Posts a message to be displayed to the user.
    /// - Parameters:
    ///   - message: The message string (should be localized).
    ///   - type: The type of message (error, success, info).
    func postMessage(_ message: String, type: MessageType) {
        // Ensure this runs on the main thread as it updates a @Published property
        updateUIState {
             self.appMessage = AppMessage(type: type, message: message)
             // Optionally clear the message after a delay
             // TODO: Implement auto-dismiss logic if desired
        }
    }
    
    // MARK: - Initialization
    
    init() {
        // Pass the postMessage function to the handlers if they need it
        self.messageHandler.messagePoster = { [weak self] message, type in
            Task { @MainActor in
                self?.postMessage(message, type: type)
            }
        } // Inject posting capability

        loadSshConfig()
        loadKubeConfig() // 仍然加载主 Kubeconfig 以获取当前配置
        loadKubeConfigFiles() // 加载所有配置文件

        // Setup event handling
        setupEventHandling()
    }
    
    // MARK: - 公共方法
    
    // 安全切换选中的主机条目
    func safelySelectEntry(_ entry: (any Identifiable)?) {
        Task {
            if isEditing {
                await MainActor.run { isEditing = false }
            }
            try? await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
            await MainActor.run { selectedEntry = entry }
        }
    }
    
    // 加载配置
    func loadSshConfig() {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { [sshFileManager, sshParser] in
                let content = try await sshFileManager.readConfigFile()
                return try await Task.detached {
                    return sshParser.parseConfig(content: content)
                }.value
            }
            isLoading = false
            
            switch result {
            case .success(let parsedEntries):
                self.sshEntries = parsedEntries
                if !parsedEntries.isEmpty && selectedConfigurationType == .ssh {
                    messageHandler.show(MessageConstants.SuccessMessages.configLoaded, type: .success)
                }
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
                sshEntries = []
            }
        }
    }
    
    // 保存配置
    func saveSshConfig() {
        Task {
            guard selectedConfigurationType == .ssh else { return }
            isLoading = true
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw ConfigForgeError.unknown("ViewModel已被释放")
                }
                let formattedContent = try await Task.detached { [entries = self.sshEntries, parser = self.sshParser] in
                    return parser.formatConfig(entries: entries)
                }.value
                try await self.sshFileManager.writeConfigFile(content: formattedContent)
                return ()
            }
            
            isLoading = false
            switch result {
            case .success:
                messageHandler.show(MessageConstants.SuccessMessages.configSaved, type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 添加新条目
    func addSshEntry(host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            messageHandler.show(MessageConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        if sshEntries.contains(where: { $0.host == host }) {
            messageHandler.show(MessageConstants.ErrorMessages.duplicateHostError, type: .error)
            return
        }
        
        let newEntry = SSHConfigEntry(host: host, properties: properties)
        sshEntries.append(newEntry)
        safelySelectEntry(newEntry)
        messageHandler.show(MessageConstants.SuccessMessages.entryAdded, type: .success)
        saveSshConfig()
    }
    
    // 更新条目
    func updateSshEntry(id: UUID, host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            messageHandler.show(MessageConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        if let index = sshEntries.firstIndex(where: { $0.id == id }) {
            let otherEntries = sshEntries.filter { $0.id != id }
            if otherEntries.contains(where: { $0.host == host }) {
                messageHandler.show(MessageConstants.ErrorMessages.duplicateHostError, type: .error)
                return
            }
            
            var updatedEntry = SSHConfigEntry(host: host, properties: properties)
            sshEntries[index] = updatedEntry
            safelySelectEntry(updatedEntry)
            messageHandler.show(MessageConstants.SuccessMessages.entryUpdated, type: .success)
            saveSshConfig()
        }
    }
    
    // 删除条目
    func deleteSshEntry(id: UUID) {
        if let index = sshEntries.firstIndex(where: { $0.id == id }) {
            let entryToDelete = sshEntries[index]
            sshEntries.remove(at: index)
            if let currentSelection = selectedEntry as? SSHConfigEntry, currentSelection.id == entryToDelete.id {
                safelySelectEntry(nil)
            }
            messageHandler.show(MessageConstants.SuccessMessages.entryDeleted, type: .success)
            saveSshConfig()
        }
    }
    
    // 备份配置
    func backupSshConfig(to url: URL) {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw ConfigForgeError.unknown("ViewModel已被释放")
                }
                let content = try await Task.detached { [entries = self.sshEntries, parser = self.sshParser] in
                    return parser.formatConfig(entries: entries)
                }.value
                try await self.sshFileManager.backupConfigFile(content: content, to: url)
                return ()
            }
            
            isLoading = false
            switch result {
            case .success:
                messageHandler.show(MessageConstants.SuccessMessages.configBackedUp, type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 恢复配置
    func restoreSshConfig(from url: URL) async {
        isLoading = true // Ensure isLoading is set at the start
        let result = await asyncUtility.perform { [sshFileManager, sshParser] in // Capture necessary components
            // Read content from the security-scoped URL
            let content = try String(contentsOf: url, encoding: .utf8)
            
            // Detach parsing as it might be CPU intensive
            let parsedEntries = try await Task.detached {
                return try sshParser.parseConfig(content: content)
            }.value
            
            // Write the restored content back to the default config file
            // Note: This overwrites the user's existing ~/.ssh/config
            try await sshFileManager.writeConfigFile(content: content)
            
            return parsedEntries
        }
        // isLoading = false // Moved isLoading = false to restoreCurrentConfig

        switch result {
        case .success(let parsedEntries):
            // Update the main entries on the main thread
            self.sshEntries = parsedEntries
            // Optionally re-select the first entry or clear selection
            safelySelectEntry(self.sshEntries.first)
            messageHandler.show(MessageConstants.SuccessMessages.configRestored, type: .success)
        case .failure(let error):
            ErrorHandler.handle(error, messageHandler: messageHandler)
            // Decide on behavior: clear entries, keep old ones, show specific error?
            // loadSshConfig() // Could reload the (potentially overwritten) file
        }
    }
    
    // 加载 Kubeconfig (仍然需要保留以获取当前活动配置信息)
    func loadKubeConfig() {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { 
                let manager = KubeConfigFileManager()
                let loadResult = manager.loadConfig()
                switch loadResult {
                case .success(let config):
                    return config 
                case .failure(let error):
                    throw error
                }
            }
            isLoading = false

            switch result {
            case .success(let loadedConfig):
                self.kubeConfig = loadedConfig

                if selectedConfigurationType == .kubernetes {
                    messageHandler.show("Kubeconfig 加载成功", type: .success)
                }

            case .failure(let error):
                if case ConfigForgeError.kubeConfigNotFound = error {
                    self.kubeConfig = KubeConfig(apiVersion: nil, kind: nil, clusters: [], contexts: [], users: [], currentContext: nil)
                } else {
                    ErrorHandler.handle(error, messageHandler: messageHandler)
                    self.kubeConfig = nil
                }
            }
        }
    }
    
    // MARK: - Kubernetes Config Files Management
    
    /// 加载 Kubernetes 配置文件列表
    func loadKubeConfigFiles() {
        Task {
            isLoadingConfigFiles = true
            
            let result = await asyncUtility.perform {
                let fileManager = KubeConfigFileManager()
                let discoverResult = await fileManager.discoverConfigFiles()
                
                switch discoverResult {
                case .success(let files):
                    // 加载每个配置文件的内容
                    let loadResult = await fileManager.loadConfigFiles(files)
                    switch loadResult {
                    case .success(let loadedFiles):
                        return loadedFiles
                    case .failure(let error):
                        throw error
                    }
                case .failure(let error):
                    throw error
                }
            }
            
            isLoadingConfigFiles = false
            
            switch result {
            case .success(let files):
                self.configFiles = files
                if selectedConfigurationType == .kubernetes {
                    if !files.isEmpty {
                        messageHandler.show("加载了 \(files.count) 个配置文件", type: .success)
                    }
                }
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
                self.configFiles = []
            }
        }
    }
    
    /// 刷新配置文件列表
    func refreshKubeConfigFiles() {
        loadKubeConfigFiles()
    }
    
    /// 选择配置文件
    func selectConfigFile(_ configFile: KubeConfigFile) {
        self.selectedConfigFile = configFile
        
        // 加载配置文件内容
        Task {
            do {
                let fileContent = try String(contentsOf: configFile.filePath, encoding: .utf8)
                await MainActor.run {
                    self.selectedConfigFileContent = fileContent
                }
            } catch {
                messageHandler.show("无法读取配置文件内容: \(error.localizedDescription)", type: .error)
                await MainActor.run {
                    self.selectedConfigFileContent = "# 错误: 无法读取文件内容\n# \(error.localizedDescription)"
                }
            }
        }
    }
    
    /// 保存配置文件内容
    func saveConfigFileContent(_ content: String) async {
        guard let configFile = selectedConfigFile else { return }
        
        do {
            // 保存文件
            let fileUtils = FileSystemUtils.shared
            let writeResult = fileUtils.writeFile(content: content, to: configFile.filePath)
            if case .failure(let error) = writeResult {
                throw error
            }
            
            // 尝试解析保存的内容
            if let parsedConfig = try? KubeConfigParser().decode(from: content).get() {
                // 更新配置文件对象
                var updatedFile = configFile
                updatedFile.updateConfig(parsedConfig)
                
                // 更新视图模型状态
                await MainActor.run {
                    // 更新配置文件列表中的条目
                    if let index = configFiles.firstIndex(where: { $0.id == configFile.id }) {
                        configFiles[index] = updatedFile
                    }
                    
                    // 更新选中的配置文件
                    selectedConfigFile = updatedFile
                    selectedConfigFileContent = content
                    
                    // 显示成功消息
                    messageHandler.show("配置已保存", type: .success)
                }
                
                // 如果是活动配置，重新加载主配置
                if configFile.fileType == .active {
                    loadKubeConfig()
                }
            } else {
                // 解析失败但保存成功
                messageHandler.show("配置已保存，但解析失败", type: .error)
            }
        } catch {
            // 保存失败
            messageHandler.show("保存配置失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// 激活配置文件 (设为主配置)
    func activateConfigFile(_ configFile: KubeConfigFile) {
        guard configFile.status == .valid else {
            messageHandler.show("无法激活无效的配置文件", type: .error)
            return
        }
        
        Task {
            isLoading = true
            
            do {
                // 读取要激活的配置文件内容
                let fileContent = try String(contentsOf: configFile.filePath, encoding: .utf8)
                
                // 创建备份
                let fileManager = KubeConfigFileManager()
                let backupResult = await fileManager.createDefaultBackup()
                if case .failure(let error) = backupResult {
                    throw error
                }
                
                // 获取主配置文件路径
                let mainConfigPath = try fileManager.getConfigFilePath()
                
                // 写入主配置文件
                try fileContent.write(to: mainConfigPath, atomically: true, encoding: .utf8)
                
                // 重新加载配置和配置文件列表
                loadKubeConfig()
                loadKubeConfigFiles()
                
                messageHandler.show("\(configFile.displayName) 已设为活动配置", type: .success)
            } catch {
                messageHandler.show("设置活动配置失败: \(error.localizedDescription)", type: .error)
            }
            
            isLoading = false
        }
    }
    
    /// 提示重命名配置文件
    func promptForRenameConfigFile(_ configFile: KubeConfigFile) {
        // 提示用户输入新名称
        let alert = NSAlert()
        alert.messageText = "重命名配置文件"
        alert.informativeText = "请输入新的文件名:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "新文件名"
        textField.stringValue = configFile.displayName
        
        alert.accessoryView = textField
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty && newName != configFile.displayName {
                renameConfigFile(configFile, to: newName)
            }
        }
    }
    
    /// 重命名配置文件
    func renameConfigFile(_ configFile: KubeConfigFile, to newName: String) {
        guard !newName.isEmpty else {
            messageHandler.show("文件名不能为空", type: .error)
            return
        }
        
        // 执行一个完全自包含的重命名操作，避免所有文件监控相关问题
        do {
            // 停止文件监控
            let eventManager = EventManager.shared
            let fileWatcher = eventManager.getFileWatcher()
            fileWatcher.stopAllWatching()
            
            let fileManager = KubeConfigFileManager()
            let configsDir = try fileManager.getConfigsDirectoryPath()
            
            // 确保新名称有正确的扩展名
            var newFileName = newName
            if !newFileName.hasSuffix(".yaml") && !newFileName.hasSuffix(".yml") {
                newFileName += ".yaml"
            }
            
            let newFilePath = configsDir.appendingPathComponent(newFileName)
            
            // 检查新文件名是否已存在
            if FileManager.default.fileExists(atPath: newFilePath.path) {
                messageHandler.show("文件 \(newFileName) 已存在", type: .error)
                
                // 重新启动文件监控
                _ = eventManager.startWatchingConfigDirectory()
                _ = eventManager.startWatchingMainConfig()
                return
            }
            
            // 保存旧文件路径
            let oldFilePath = configFile.filePath
            
            // 读取原文件内容
            let fileContent: String
            do {
                fileContent = try String(contentsOf: oldFilePath, encoding: .utf8)
            } catch {
                messageHandler.show("读取文件内容失败: \(error.localizedDescription)", type: .error)
                
                // 重新启动文件监控
                _ = eventManager.startWatchingConfigDirectory()
                _ = eventManager.startWatchingMainConfig()
                return
            }
            
            // 写入新文件
            do {
                try fileContent.write(to: newFilePath, atomically: true, encoding: .utf8)
            } catch {
                messageHandler.show("创建新文件失败: \(error.localizedDescription)", type: .error)
                
                // 重新启动文件监控
                _ = eventManager.startWatchingConfigDirectory()
                _ = eventManager.startWatchingMainConfig()
                return
            }
            
            // 删除旧文件
            do {
                try FileManager.default.removeItem(at: oldFilePath)
            } catch {
                // 即使删除旧文件失败，我们也认为重命名成功了
                print("删除旧文件失败: \(error.localizedDescription)")
            }
            
            // 取消当前选择
            if self.selectedConfigFile?.id == configFile.id {
                self.selectedConfigFile = nil
                self.selectedConfigFileContent = ""
            }
            
            // 清除缓存信息
            self.configFiles.removeAll(where: { $0.id == configFile.id })
            
            // 重新启动文件监控
            _ = eventManager.startWatchingConfigDirectory()
            _ = eventManager.startWatchingMainConfig()
            
            // 重新加载配置文件列表
            loadKubeConfigFiles()
            
            // 显示成功消息
            messageHandler.show("文件已重命名为 \(newFileName)", type: .success)
            
            // 选择新文件
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // 找到新文件并选择它
                if let newFile = self.configFiles.first(where: { $0.filePath.path == newFilePath.path }) {
                    self.selectConfigFile(newFile)
                }
            }
        } catch {
            messageHandler.show("重命名文件失败: \(error.localizedDescription)", type: .error)
            
            // 重新启动文件监控
            _ = EventManager.shared.startWatchingConfigDirectory()
            _ = EventManager.shared.startWatchingMainConfig()
        }
    }
    
    /// 提示删除配置文件
    func promptForDeleteConfigFile(_ configFile: KubeConfigFile) {
        // 显示确认对话框
        let alert = NSAlert()
        alert.messageText = "删除配置文件"
        alert.informativeText = "确定要删除 \(configFile.displayName) 吗？此操作不可恢复。"
        alert.alertStyle = .warning
        alert.addButton(withTitle: "删除")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            deleteConfigFile(configFile)
        }
    }
    
    /// 删除配置文件
    func deleteConfigFile(_ configFile: KubeConfigFile) {
        // 不使用异步任务，直接在主线程上执行，避免多线程操作导致的问题
        do {
            // 如果是当前选中的文件，先清除选择
            let wasSelected = (self.selectedConfigFile?.id == configFile.id)
            if wasSelected {
                self.selectedConfigFile = nil
                self.selectedConfigFileContent = ""
            }
            
            // 先取消监控文件
            EventManager.shared.publish(.configFileRemoved(configFile.filePath))
            
            // 删除文件
            try FileManager.default.removeItem(at: configFile.filePath)
            
            // 先显示成功消息
            messageHandler.show("\(configFile.displayName) 已删除", type: .success)
            
            // 延迟执行后续操作，让FileWatcher先处理完文件系统事件
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                guard let self = self else { return }
                
                // 重新加载配置文件列表
                self.loadKubeConfigFiles()
            }
        } catch {
            messageHandler.show("删除文件失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    /// 创建新配置文件
    func createNewConfigFile() {
        Task {
            do {
                // 创建一个基本的空 Kubernetes 配置
                let emptyConfig = """
                apiVersion: v1
                kind: Config
                clusters:
                - name: my-cluster
                  cluster:
                    server: https://example.com
                contexts:
                - name: my-context
                  context:
                    cluster: my-cluster
                    user: my-user
                users:
                - name: my-user
                  user:
                    token: placeholder-token
                current-context: my-context
                """
                
                // 获取配置目录
                let fileManager = KubeConfigFileManager()
                let configsDir = try fileManager.getConfigsDirectoryPath()
                
                // 创建唯一的文件名
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                    .replacingOccurrences(of: " ", with: "_")
                
                let newFileName = "new-config-\(timestamp).yaml"
                let newFilePath = configsDir.appendingPathComponent(newFileName)
                
                // 写入新文件
                try emptyConfig.write(to: newFilePath, atomically: true, encoding: .utf8)
                
                // 重新加载配置文件列表
                loadKubeConfigFiles()
                
                // 如果创建成功，选择新文件
                if let newFile = configFiles.first(where: { $0.fileName == newFileName }) {
                    selectConfigFile(newFile)
                }
                
                messageHandler.show("已创建新配置文件", type: .success)
            } catch {
                messageHandler.show("创建新配置文件失败: \(error.localizedDescription)", type: .error)
            }
        }
    }
    
    // MARK: - 辅助方法
    
    // 获取消息处理器（用于视图绑定）
    func getMessageHandler() -> MessageHandler {
        messageHandler
    }
    
    // 获取异步工具（用于视图绑定）
    func getAsyncUtility() -> AsyncUtility {
        asyncUtility
    }
    
    // MARK: - Unified Save/Backup/Restore
    
    func saveCurrentConfig() {
        switch selectedConfigurationType {
        case .ssh:
            saveSshConfig() // Call existing SSH save method
        case .kubernetes:
            saveKubeConfig() // Call new Kube save method
        }
    }
    
    // 保存 Kubeconfig
    func saveKubeConfig() {
        Task {
            isLoading = true
            
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self, let config = await self.kubeConfig else { 
                    throw ConfigForgeError.configRead("KubeConfig未加载或已被释放")
                }
                
                // 在闭包内创建实例，而不是使用实例变量
                let fileManager = KubeConfigFileManager()
                return try await fileManager.saveConfig(config: config)
            }
            
            isLoading = false
            switch result {
            case .success:
                messageHandler.show("Kubeconfig 保存成功", type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 备份 Kubeconfig
    func backupKubeConfig(to url: URL) {
        Task {
            guard let config = self.kubeConfig else {
                messageHandler.show("错误：无法备份，KubeConfig 未加载。", type: .error)
                return
            }
            
            isLoading = true
            let result = await asyncUtility.perform { 
                let fileManager = KubeConfigFileManager()
                do {
                    try await fileManager.backupConfig(config: config, to: url)
                    return ()
                } catch {
                    throw error
                }
            }
            isLoading = false

            switch result {
            case .success:
                messageHandler.show("Kubeconfig 已成功备份到 \(url.lastPathComponent)。", type: .success)
            case .failure(let error):
                messageHandler.show("备份 Kubeconfig 失败：\(error.localizedDescription)", type: .error)
            }
        }
    }

    // 恢复 Kubeconfig
    func restoreKubeConfig(from url: URL) async {
        isLoading = true
        let result = await asyncUtility.perform { 
            let fileManager = KubeConfigFileManager()
            do {
                return try await fileManager.restoreConfig(from: url)
            } catch {
                throw error
            }
        }
        
        switch result {
        case .success(let restoredConfig):
            // 更新视图模型中的数据
            self.kubeConfig = restoredConfig
            
            messageHandler.show("Kubeconfig 已从 \(url.lastPathComponent) 成功恢复。", type: .success)
        case .failure(let error):
            messageHandler.show("恢复 Kubeconfig 失败：\(error.localizedDescription)", type: .error)
            // 重新加载现有配置
            loadKubeConfig()
        }
        
        isLoading = false
    }
    
    // 统一恢复配置
    func restoreCurrentConfig(from url: URL) {
        Task {
            isLoading = true
            print("--- Triggered: restoreCurrentConfig for type: \(selectedConfigurationType) from URL: \(url.path) ---")
            switch selectedConfigurationType {
            case .ssh:
                await restoreSshConfig(from: url)
            case .kubernetes:
                await restoreKubeConfig(from: url)
            }
            isLoading = false
        }
    }
    
    // MARK: - 事件处理

    /// 设置事件处理
    private func setupEventHandling() {
        // 启动文件监控
        startFileWatching()
        
        // 订阅应用程序事件
        EventManager.shared.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                
                switch event {
                case .configFileAdded(let url):
                    // 新配置文件添加，重新加载配置文件列表
                    Task { @MainActor in
                        await self.reloadConfigFileByURL(url)
                    }
                    
                case .configFileChanged(let url):
                    // 配置文件变更，更新内容
                    Task { @MainActor in
                        await self.reloadConfigFileByURL(url)
                    }
                    
                case .configFileRemoved(let url):
                    // 配置文件被删除，从列表中移除
                    Task { @MainActor in
                        self.removeConfigFile(url)
                    }
                    
                case .activeConfigChanged(let config):
                    // 活动配置变更
                    Task { @MainActor in
                        self.kubeConfig = config
                    }
                    
                case .reloadConfigRequested:
                    // 请求重新加载配置
                    loadKubeConfigFiles()
                    
                case .notification(let message, let type):
                    // 显示通知
                    messageHandler.show(message, type: type)
                }
            }
            .store(in: &cancellables)
    }

    /// 启动文件监控
    private func startFileWatching() {
        // 开始监控配置目录
        _ = EventManager.shared.startWatchingConfigDirectory()
        
        // 开始监控主配置文件
        _ = EventManager.shared.startWatchingMainConfig()
    }

    /// 加载指定路径的配置文件
    /// - Parameter url: 配置文件URL
    /// - Returns: 加载的配置文件对象
    private func loadConfigFile(at url: URL) async throws -> KubeConfigFile {
        // 确保文件存在
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigForgeError.fileAccess("文件不存在")
        }
        
        // 确定文件类型
        let fileType: KubeConfigFileType
        let fileManager = KubeConfigFileManager()
        
        let mainConfigPath = try? fileManager.getConfigFilePath().path
        if url.path == mainConfigPath {
            fileType = .active
        } else {
            let backupPath = try? fileManager.getConfigBackupFilePath().path
            if url.path == backupPath {
                fileType = .backup
            } else {
                fileType = .stored
            }
        }
        
        // 创建配置文件对象
        guard var configFile = KubeConfigFile.from(url: url, fileType: fileType) else {
            throw ConfigForgeError.unknown("无法创建配置文件对象")
        }
        
        // 读取和解析文件内容
        do {
            let content = try String(contentsOf: url, encoding: .utf8)
            let parser = KubeConfigParser()
            let parseResult = parser.decode(from: content)
            
            switch parseResult {
            case .success(let config):
                // 更新配置文件状态
                configFile.updateConfig(config)
                return configFile
            case .failure(let error):
                // 标记为无效，但仍然返回配置文件对象
                configFile.markAsInvalid(error.localizedDescription)
                return configFile
            }
        } catch {
            // 读取失败，标记为无效
            configFile.markAsInvalid("读取文件失败: \(error.localizedDescription)")
            return configFile
        }
    }

    /// 根据URL重新加载特定配置文件
    private func reloadConfigFileByURL(_ url: URL) async {
        // 查找是否已存在此配置文件
        if let index = configFiles.firstIndex(where: { $0.filePath == url }) {
            // 更新现有配置文件
            do {
                let updatedFile = try await loadConfigFile(at: url)
                configFiles[index] = updatedFile
                
                // 如果是当前选中的文件，更新内容
                if selectedConfigFile?.filePath == url {
                    selectedConfigFile = updatedFile
                    do {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        selectedConfigFileContent = content
                    } catch {
                        print("读取文件内容失败: \(error.localizedDescription)")
                    }
                }
                
                // 如果是活动配置，更新主配置
                if updatedFile.fileType == .active {
                    loadKubeConfig()
                }
            } catch {
                print("更新配置文件失败: \(error.localizedDescription)")
            }
        } else {
            // 新文件，加载配置文件列表
            loadKubeConfigFiles()
        }
    }

    /// 从列表中移除配置文件
    private func removeConfigFile(_ url: URL) {
        // 查找是否存在此配置文件
        if let index = configFiles.firstIndex(where: { $0.filePath == url }) {
            // 如果是当前选中的文件，取消选择
            if selectedConfigFile?.filePath == url {
                selectedConfigFile = nil
                selectedConfigFileContent = ""
            }
            
            // 从列表中移除
            configFiles.remove(at: index)
        }
    }

    /// 用于存储取消的订阅
    private var cancellables = Set<AnyCancellable>()
}
