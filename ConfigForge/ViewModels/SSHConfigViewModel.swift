//
//  SSHConfigViewModel.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

class SSHConfigViewModel: ObservableObject {
    @Published var entries: [SSHConfigEntry] = []
    @Published var searchText: String = ""
    @Published var selectedEntry: SSHConfigEntry?
    @Published var isEditing: Bool = false
    @Published var errorMessage: String?
    
    private let fileManager = SSHConfigFileManager()
    private let parser = SSHConfigParser()
    
    // 初始化和加载配置
    init() {
        loadConfig()
    }
    
    // 过滤后的条目列表
    var filteredEntries: [SSHConfigEntry] {
        if searchText.isEmpty {
            return entries.sorted { $0.host < $1.host }
        } else {
            return entries.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
                .sorted { $0.host < $1.host }
        }
    }
    
    // 加载SSH配置
    func loadConfig() {
        let result = fileManager.readConfigFile()
        
        switch result {
        case .success(let content):
            entries = parser.parseConfig(content: content)
        case .failure(let error):
            errorMessage = "无法加载SSH配置文件: \(error.localizedDescription)"
            entries = []
        }
    }
    
    // 保存SSH配置
    func saveConfig() {
        let content = parser.formatConfig(entries: entries)
        let result = fileManager.writeConfigFile(content: content)
        
        switch result {
        case .success:
            errorMessage = nil
        case .failure(let error):
            errorMessage = "保存配置文件失败: \(error.localizedDescription)"
        }
    }
    
    // 添加新条目
    func addEntry(host: String, properties: [String: String]) {
        let newEntry = SSHConfigEntry(host: host, properties: properties)
        
        if parser.validateEntry(entry: newEntry, existingEntries: entries) {
            entries.append(newEntry)
            saveConfig()
        } else {
            errorMessage = "无效的配置条目或Host名称已存在"
        }
    }
    
    // 更新现有条目
    func updateEntry(id: UUID, host: String, properties: [String: String]) {
        guard let index = entries.firstIndex(where: { $0.id == id }) else {
            errorMessage = "找不到要更新的条目"
            return
        }
        
        let updatedEntry = SSHConfigEntry(id: id, host: host, properties: properties)
        
        // 如果只是更新自身，不需要检查Host冲突
        let otherEntries = entries.filter { $0.id != id }
        
        if parser.validateEntry(entry: updatedEntry, existingEntries: otherEntries) {
            entries[index] = updatedEntry
            saveConfig()
        } else {
            errorMessage = "无效的配置条目或Host名称已存在"
        }
    }
    
    // 删除条目
    func deleteEntry(id: UUID) {
        entries.removeAll { $0.id == id }
        saveConfig()
    }
    
    // 备份配置
    func backupConfig(to destination: URL?) {
        guard let destination = destination else {
            let desktopURL = fileManager.fileManager.urls(for: .desktopDirectory, in: .userDomainMask).first!
            backupConfig(to: desktopURL)
            return
        }
        
        let result = fileManager.backupConfigFile(to: destination)
        
        switch result {
        case .success(let url):
            errorMessage = nil
            // 可以展示成功信息，如: "备份已保存至 \(url.path)"
        case .failure(let error):
            errorMessage = "备份失败: \(error.localizedDescription)"
        }
    }
    
    // 从备份恢复
    func restoreConfig(from source: URL?) {
        guard let source = source else {
            errorMessage = "未选择备份文件"
            return
        }
        
        let result = fileManager.restoreConfigFile(from: source)
        
        switch result {
        case .success:
            errorMessage = nil
            loadConfig() // 重新加载配置
        case .failure(let error):
            errorMessage = "恢复失败: \(error.localizedDescription)"
        }
    }
}
