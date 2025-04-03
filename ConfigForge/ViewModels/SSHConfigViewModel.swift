//
//  SSHConfigViewModel.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

// 消息类型枚举
enum MessageType {
    case error
    case success
    case info
}

// 可识别的消息结构体
struct AppMessage: Identifiable {
    let id: UUID
    let type: MessageType
    let message: String
    
    init(id: UUID = UUID(), type: MessageType, message: String) {
        self.id = id
        self.type = type
        self.message = message
    }
}

@MainActor
class SSHConfigViewModel: ObservableObject {
    @Published var entries: [SSHConfigEntry] = []
    @Published var searchText: String = ""
    @Published var selectedEntry: SSHConfigEntry?
    @Published var isEditing: Bool = false
    @Published var errorMessage: String?
    @Published var appMessage: AppMessage?
    @Published var isLoading: Bool = false
    
    let fileManager = SSHConfigFileManager()
    let parser = SSHConfigParser()
    
    // 初始化和加载配置
    init() {
        loadConfig()
    }
    
    // 过滤后的条目列表
    var filteredEntries: [SSHConfigEntry] {
        var filtered = entries
        
        // 按搜索文本过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 最后按主机名排序
        return filtered.sorted { $0.host < $1.host }
    }
    
    // 安全切换选中的主机条目
    func safelySelectEntry(_ entry: SSHConfigEntry?) {
        Task {
            // 如果正在编辑，先关闭编辑模式
            if isEditing {
                await MainActor.run {
                    isEditing = false
                }
            }
            
            // 确保UI有时间更新
            try? await Task.sleep(for: .milliseconds(50))
            
            // 然后切换选中项
            await MainActor.run {
                selectedEntry = entry
            }
        }
    }
    
    // 设置消息
    func setMessage(_ message: String, type: MessageType = .info) {
        let messageId = UUID()
        appMessage = AppMessage(id: messageId, type: type, message: message)
        
        // 如果是错误消息，同时设置errorMessage保持兼容性
        if type == .error {
            errorMessage = message
        } else {
            errorMessage = nil
            
            // 消息显示5秒后自动清除成功和信息消息（增加时间以确保用户能看到）
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(5))
                await MainActor.run {
                    guard let self = self else { return }
                    if self.appMessage?.id == messageId {
                        self.appMessage = nil
                    }
                }
            }
        }
    }
    
    // 异步加载SSH配置
    func loadConfig() {
        Task {
            await loadConfigAsync()
        }
    }
    
    private func loadConfigAsync() async {
        await MainActor.run {
            isLoading = true
        }
        
        // 创建对文件管理器的隔离副本
        let fileManagerCopy = fileManager
        
        // 在后台线程执行文件操作，不使用@MainActor隔离的成员
        let result = await Task.detached { @Sendable in
            return fileManagerCopy.readConfigFile()
        }.value
        
        // 返回主线程更新UI
        await MainActor.run {
            isLoading = false
            
            switch result {
            case .success(let content):
                // 文件内容解析也可能耗时，创建单独的任务
                Task {
                    // 创建解析器的隔离副本
                    let parserCopy = self.parser
                    
                    let parsedEntries = await Task.detached { @Sendable in
                        return parserCopy.parseConfig(content: content)
                    }.value
                    
                    await MainActor.run {
                        self.entries = parsedEntries
                        if !parsedEntries.isEmpty {
                            self.setMessage("message.config.loaded".localized, type: .success)
                        }
                    }
                }
                
            case .failure(let error):
                setMessage(AppConstants.ErrorMessages.fileAccessError + ": \(error.localizedDescription)", type: .error)
                entries = []
            }
        }
    }
    
    // 异步保存SSH配置
    func saveConfig() {
        Task {
            await saveConfigAsync()
        }
    }
    
    private func saveConfigAsync() async {
        await MainActor.run {
            isLoading = true
        }
        
        // 在主线程捕获所需的数据和对象
        let entriesCopy = entries // 捕获当前entries的快照
        let parserCopy = parser
        
        // 在独立任务中进行格式化，避免数据竞争
        let formattingResult = await Task.detached { @Sendable in
            return parserCopy.formatConfig(entries: entriesCopy)
        }.value
        
        // 准备文件管理器副本
        let fileManagerCopy = fileManager
        
        // 在独立任务中执行文件写入
        let writeResult = await Task.detached { @Sendable in
            return fileManagerCopy.writeConfigFile(content: formattingResult)
        }.value
        
        // 返回主线程更新UI
        await MainActor.run {
            isLoading = false
            
            switch writeResult {
            case .success:
                setMessage("message.config.saved".localized, type: .success)
            case .failure(let error):
                setMessage("message.error.export.failed".localized(error.localizedDescription), type: .error)
            }
        }
    }
    
    // 添加新条目
    func addEntry(host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            setMessage(AppConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        // 如果是本地化的新主机标识，使用原始标识符
        let finalHost = (host == "host.new".localized) ? "host.new" : host
        
        // 创建一个包含默认值的属性副本
        var finalProperties = properties
        
        // 确保基本属性有值
        if finalProperties["Port"] == nil || finalProperties["Port"]!.isEmpty {
            finalProperties["Port"] = "22"
        }
        
        // 确保包含HostName和IdentityFile
        if finalProperties["HostName"] == nil {
            finalProperties["HostName"] = ""
        }
        
        if finalProperties["IdentityFile"] == nil {
            finalProperties["IdentityFile"] = ""
        }
        
        let newEntry = SSHConfigEntry(host: finalHost, properties: finalProperties)
        
        if parser.validateEntry(entry: newEntry, existingEntries: entries) {
            entries.append(newEntry)
            saveConfig()
            setMessage("message.host.added".localized(finalHost), type: .success)
            // 选择新添加的条目
            selectedEntry = newEntry
        } else {
            setMessage(AppConstants.ErrorMessages.duplicateHostError, type: .error)
        }
    }
    
    // 更新现有条目
    func updateEntry(id: UUID, host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            setMessage(AppConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        // 如果是本地化的新主机标识，使用原始标识符
        let finalHost = (host == "host.new".localized) ? "host.new" : host
        
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            setMessage(AppConstants.ErrorMessages.entryNotFoundError, type: .error)
            return
        }
        
        // 创建一个包含默认值的属性副本
        var finalProperties = properties
        
        // 确保基本属性有值
        if finalProperties["Port"] == nil || finalProperties["Port"]!.isEmpty {
            finalProperties["Port"] = "22"
        }
        
        // 确保包含HostName和IdentityFile
        if finalProperties["HostName"] == nil {
            finalProperties["HostName"] = ""
        }
        
        if finalProperties["IdentityFile"] == nil {
            finalProperties["IdentityFile"] = ""
        }
        
        // 创建一个临时条目来验证
        let updatedEntry = SSHConfigEntry(host: finalHost, properties: finalProperties)
        
        // 使用模型中的验证方法
        if !updatedEntry.isPortValid {
            setMessage(AppConstants.ErrorMessages.invalidPortError, type: .error)
            return
        }
        
        // 如果只是更新自身，不需要检查Host冲突
        let otherEntries = entries.filter { $0.id != id }
        
        if parser.validateEntry(entry: updatedEntry, existingEntries: otherEntries) {
            entries[index] = updatedEntry
            saveConfig()
            setMessage("message.host.updated".localized(finalHost), type: .success)
            // 更新选定条目
            selectedEntry = updatedEntry
        } else {
            setMessage(AppConstants.ErrorMessages.duplicateHostError, type: .error)
        }
    }
    
    // 删除条目
    func deleteEntry(id: UUID) {
        if let hostToDelete = entries.first(where: { $0.id == id })?.host {
            entries.removeAll { $0.id == id }
            saveConfig()
            setMessage("message.host.deleted".localized(hostToDelete), type: .success)
        }
    }
    
    // 异步备份配置
    func backupConfig(to destination: URL?) {
        Task {
            await backupConfigAsync(to: destination)
        }
    }
    
    private func backupConfigAsync(to destination: URL?) async {
        guard let destination = destination else {
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            await backupConfigAsync(to: desktopURL)
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        // 创建文件管理器副本
        let fileManagerCopy = fileManager
        
        // 使用独立任务执行备份操作
        let result = await Task.detached { @Sendable in
            return fileManagerCopy.backupConfigFile(to: destination)
        }.value
        
        await MainActor.run {
            isLoading = false
            
            switch result {
            case .success(let url):
                setMessage("message.backup.success".localized(url.lastPathComponent), type: .success)
            case .failure(let error):
                setMessage(AppConstants.ErrorMessages.backupFailed + ": \(error.localizedDescription)", type: .error)
            }
        }
    }
    
    // 异步恢复配置
    func restoreConfig(from source: URL?) {
        Task {
            await restoreConfigAsync(from: source)
        }
    }
    
    private func restoreConfigAsync(from source: URL?) async {
        guard let source = source else {
            setMessage("message.error.backup.not.selected".localized, type: .error)
            return
        }
        
        await MainActor.run {
            isLoading = true
        }
        
        // 创建文件管理器副本
        let fileManagerCopy = fileManager
        
        // 使用独立任务执行恢复操作
        let result = await Task.detached { @Sendable in
            return fileManagerCopy.restoreConfigFile(from: source)
        }.value
        
        await MainActor.run {
            isLoading = false
            
            switch result {
            case .success:
                // 使用Task包装异步调用
                Task { 
                    await loadConfigAsync() // 重新加载配置
                    setMessage("message.restore.success".localized, type: .success)
                }
            case .failure(let error):
                setMessage(AppConstants.ErrorMessages.restoreFailed + ": \(error.localizedDescription)", type: .error)
            }
        }
    }
}
