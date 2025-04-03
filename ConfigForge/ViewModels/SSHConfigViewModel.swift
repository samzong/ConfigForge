//
//  SSHConfigViewModel.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

// 消息类型枚举
enum MessageType: Sendable {
    case error
    case success
    case info
}

// 可识别的消息结构体
struct AppMessage: Identifiable, Sendable {
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
    
    private let asyncUtility = AsyncUtility()
    private let messageHandler = MessageHandler()
    private let fileManager = SSHConfigFileManager()
    let parser = SSHConfigParser()
    
    // 计算属性：过滤后的条目列表
    var filteredEntries: [SSHConfigEntry] {
        var filtered = entries
        if !searchText.isEmpty {
            filtered = filtered.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
        }
        return filtered.sorted { $0.host < $1.host }
    }
    
    // MARK: - 初始化
    init() {
        loadConfig()
    }
    
    // MARK: - 公共方法
    
    // 安全切换选中的主机条目
    func safelySelectEntry(_ entry: SSHConfigEntry?) {
        Task {
            if isEditing {
                await MainActor.run { isEditing = false }
            }
            try? await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
            await MainActor.run { selectedEntry = entry }
        }
    }
    
    // 加载配置
    func loadConfig() {
        Task {
            let result = await asyncUtility.perform { [fileManager, parser] in
                let content = try await fileManager.readConfigFile()
                return try await Task.detached {
                    return parser.parseConfig(content: content)
                }.value
            }
            
            switch result {
            case .success(let parsedEntries):
                self.entries = parsedEntries
                if !parsedEntries.isEmpty {
                    messageHandler.show(AppConstants.SuccessMessages.configLoaded, type: .success)
                }
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
                entries = []
            }
        }
    }
    
    // 保存配置
    func saveConfig() {
        Task {
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw NSError(domain: "SSHConfigViewModel", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "ViewModel已被释放"])
                }
                let formattedContent = try await Task.detached { [entries = self.entries, parser = self.parser] in
                    return parser.formatConfig(entries: entries)
                }.value
                try await self.fileManager.writeConfigFile(content: formattedContent)
                return ()
            }
            
            switch result {
            case .success:
                messageHandler.show(AppConstants.SuccessMessages.configSaved, type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 添加新条目
    func addEntry(host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            messageHandler.show(AppConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        // 检查主机名是否重复
        if entries.contains(where: { $0.host == host }) {
            messageHandler.show(AppConstants.ErrorMessages.duplicateHostError, type: .error)
            return
        }
        
        let newEntry = SSHConfigEntry(host: host, properties: properties)
        entries.append(newEntry)
        selectedEntry = newEntry
        messageHandler.show(AppConstants.SuccessMessages.entryAdded, type: .success)
    }
    
    // 更新条目
    func updateEntry(id: UUID, host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            messageHandler.show(AppConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        // 检查主机名是否与其他条目重复
        if let index = entries.firstIndex(where: { $0.id == id }) {
            let otherEntries = entries.filter { $0.id != id }
            if otherEntries.contains(where: { $0.host == host }) {
                messageHandler.show(AppConstants.ErrorMessages.duplicateHostError, type: .error)
                return
            }
            
            entries[index] = SSHConfigEntry(host: host, properties: properties)
            selectedEntry = entries[index]
            messageHandler.show(AppConstants.SuccessMessages.entryUpdated, type: .success)
        }
    }
    
    // 删除条目
    func deleteEntry(id: UUID) {
        if let index = entries.firstIndex(where: { $0.id == id }) {
            entries.remove(at: index)
            selectedEntry = nil
            messageHandler.show(AppConstants.SuccessMessages.entryDeleted, type: .success)
        }
    }
    
    // 备份配置
    func backupConfig(to url: URL) {
        Task {
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw NSError(domain: "SSHConfigViewModel", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "ViewModel已被释放"])
                }
                let content = try await Task.detached { [entries = self.entries, parser = self.parser] in
                    return parser.formatConfig(entries: entries)
                }.value
                try await self.fileManager.backupConfigFile(content: content, to: url)
                return ()
            }
            
            switch result {
            case .success:
                messageHandler.show(AppConstants.SuccessMessages.configBackedUp, type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 恢复配置
    func restoreConfig(from url: URL) {
        Task {
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw NSError(domain: "SSHConfigViewModel", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "ViewModel已被释放"])
                }
                let content = try await self.fileManager.restoreConfigFile(from: url)
                return try await Task.detached { [parser = self.parser] in
                    return parser.parseConfig(content: content)
                }.value
            }
            
            switch result {
            case .success(let restoredEntries):
                self.entries = restoredEntries
                messageHandler.show(AppConstants.SuccessMessages.configRestored, type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 获取消息处理器（用于视图绑定）
    func getMessageHandler() -> MessageHandler {
        messageHandler
    }
    
    // 获取异步工具（用于视图绑定）
    func getAsyncUtility() -> AsyncUtility {
        asyncUtility
    }
}
