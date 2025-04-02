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

// 主机分组枚举
enum HostGroup: String, CaseIterable, Identifiable {
    case personal = "个人"
    case work = "工作"
    case development = "开发"
    case production = "生产"
    case other = "其他"
    
    var id: String { self.rawValue }
    
    static func fromTag(_ tag: String?) -> HostGroup {
        guard let tag = tag else { return .other }
        
        return HostGroup.allCases.first { $0.rawValue == tag } ?? .other
    }
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
    @Published var selectedGroup: HostGroup? = nil
    
    let fileManager = SSHConfigFileManager()
    let parser = SSHConfigParser()
    
    // 初始化和加载配置
    init() {
        loadConfig()
    }
    
    // 过滤后的条目列表
    var filteredEntries: [SSHConfigEntry] {
        var filtered = entries
        
        // 先按组过滤
        if let group = selectedGroup {
            filtered = filtered.filter { entry in
                // 查找Group标签
                if let groupTag = entry.properties["Group"] {
                    return groupTag == group.rawValue
                }
                return group == .other // 如果没有Group标签，归为"其他"
            }
        }
        
        // 再按搜索文本过滤
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
        }
        
        // 最后按主机名排序
        return filtered.sorted { $0.host < $1.host }
    }
    
    // 获取特定组内的主机数量
    func entryCount(forGroup group: HostGroup) -> Int {
        if group == .other {
            return entries.filter { $0.properties["Group"] == nil }.count
        } else {
            return entries.filter { $0.properties["Group"] == group.rawValue }.count
        }
    }
    
    // 设置条目所属组
    func setGroup(forEntry entryId: UUID, group: HostGroup) {
        guard let index = entries.firstIndex(where: { $0.id == entryId }) else { return }
        
        var updatedProperties = entries[index].properties
        
        if group == .other {
            updatedProperties.removeValue(forKey: "Group")
        } else {
            updatedProperties["Group"] = group.rawValue
        }
        
        let updatedEntry = SSHConfigEntry(
            host: entries[index].host,
            properties: updatedProperties
        )
        
        entries[index] = updatedEntry
        saveConfig()
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
            
            // 3秒后自动清除成功和信息消息
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(3))
                guard let self = self else { return }
                if self.appMessage?.id == messageId {
                    self.appMessage = nil
                }
            }
        }
    }
    
    // 加载SSH配置
    func loadConfig() {
        let result = fileManager.readConfigFile()
        
        switch result {
        case .success(let content):
            entries = parser.parseConfig(content: content)
            if !entries.isEmpty {
                setMessage("配置已成功加载", type: .success)
            }
        case .failure(let error):
            setMessage(AppConstants.ErrorMessages.fileAccessError + ": \(error.localizedDescription)", type: .error)
            entries = []
        }
    }
    
    // 保存SSH配置
    func saveConfig() {
        let content = parser.formatConfig(entries: entries)
        let result = fileManager.writeConfigFile(content: content)
        
        switch result {
        case .success:
            setMessage("配置已成功保存", type: .success)
        case .failure(let error):
            setMessage("保存配置文件失败: \(error.localizedDescription)", type: .error)
        }
    }
    
    // 添加新条目
    func addEntry(host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            setMessage(AppConstants.ErrorMessages.emptyHostError, type: .error)
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
        
        let newEntry = SSHConfigEntry(host: host, properties: finalProperties)
        
        if parser.validateEntry(entry: newEntry, existingEntries: entries) {
            entries.append(newEntry)
            saveConfig()
            setMessage("已添加 \(host)", type: .success)
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
        
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            setMessage("找不到要更新的条目", type: .error)
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
        
        let updatedEntry = SSHConfigEntry(host: host, properties: finalProperties)
        
        // 如果只是更新自身，不需要检查Host冲突
        let otherEntries = entries.filter { $0.id != id }
        
        if parser.validateEntry(entry: updatedEntry, existingEntries: otherEntries) {
            entries[index] = updatedEntry
            saveConfig()
            setMessage("已更新 \(host)", type: .success)
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
            setMessage("已删除 \(hostToDelete)", type: .success)
        }
    }
    
    // 备份配置
    func backupConfig(to destination: URL?) {
        guard let destination = destination else {
            let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first!
            backupConfig(to: desktopURL)
            return
        }
        
        let result = fileManager.backupConfigFile(to: destination)
        
        switch result {
        case .success(let url):
            setMessage("配置已备份至 \(url.lastPathComponent)", type: .success)
        case .failure(let error):
            setMessage(AppConstants.ErrorMessages.backupFailed + ": \(error.localizedDescription)", type: .error)
        }
    }
    
    // 从备份恢复
    func restoreConfig(from source: URL?) {
        guard let source = source else {
            setMessage("未选择备份文件", type: .error)
            return
        }
        
        let result = fileManager.restoreConfigFile(from: source)
        
        switch result {
        case .success:
            loadConfig() // 重新加载配置
            setMessage("配置已从备份恢复", type: .success)
        case .failure(let error):
            setMessage(AppConstants.ErrorMessages.restoreFailed + ": \(error.localizedDescription)", type: .error)
        }
    }
}
