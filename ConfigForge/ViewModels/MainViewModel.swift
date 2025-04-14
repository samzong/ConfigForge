//
//  SSHConfigViewModel.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI
import Combine // Import Combine for AnyCancellable if needed later
import Foundation

// MARK: - Enums for State Management

// Type of configuration being viewed/edited
enum ConfigType: String, CaseIterable, Identifiable {
    case ssh = "SSH"
    case kubernetes = "Kubernetes"
    var id: String { self.rawValue }
}

// Type of Kubernetes object being viewed/edited
enum KubeObjectType: String, CaseIterable, Identifiable {
    case contexts = "Contexts"
    case clusters = "Clusters"
    case users = "Users"
    var id: String { self.rawValue }
}

@MainActor
class MainViewModel: ObservableObject {
    @Published var selectedConfigurationType: ConfigType = .ssh // NEW: Top level selector
    @Published var selectedKubernetesObjectType: KubeObjectType = .contexts {
        didSet {
            // Only act if we're actually changing the type
            if oldValue != selectedKubernetesObjectType {
                handleKubeObjectTypeChange(from: oldValue, to: selectedKubernetesObjectType)
            }
        }
    } // NEW: Kube internal selector
    @Published var searchText: String = ""
    @Published var selectedEntry: (any Identifiable)? // MODIFIED: Can hold SSH or Kube objects
    @Published var isEditing: Bool = false // Note: Might need adjustment depending on how editing Kube objects works
    @Published var errorMessage: String?
    @Published var appMessage: AppMessage?
    @Published var isLoading: Bool = false
    
    @Published var sshEntries: [SSHConfigEntry] = [] // Renamed from 'entries' for clarity
    @Published var kubeConfig: KubeConfig?
    @Published var kubeContexts: [KubeContext] = []
    @Published var kubeClusters: [KubeCluster] = []
    @Published var kubeUsers: [KubeUser] = []
    @Published var currentKubeContextName: String?
    
    private let asyncUtility = AsyncUtility()
    private let messageHandler = MessageHandler()
    private let sshFileManager = SSHConfigFileManager()
    private let kubeConfigFileManager = KubeConfigFileManager()
    let sshParser = SSHConfigParser()
    
    // 计算属性：过滤后的条目列表
    var displayedEntries: [any Identifiable] {
        var filtered: [any Identifiable] = []

        switch selectedConfigurationType {
        case .ssh:
            filtered = sshEntries
            if !searchText.isEmpty {
                filtered = sshEntries.filter { $0.host.localizedCaseInsensitiveContains(searchText) }
            }
            return filtered.sorted { ($0 as! SSHConfigEntry).host < ($1 as! SSHConfigEntry).host }

        case .kubernetes:
            switch selectedKubernetesObjectType {
            case .contexts:
                filtered = kubeContexts
                if !searchText.isEmpty {
                    filtered = kubeContexts.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                }
                return filtered.sorted { ($0 as! KubeContext).name < ($1 as! KubeContext).name }
            case .clusters:
                filtered = kubeClusters
                if !searchText.isEmpty {
                    filtered = kubeClusters.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                }
                return filtered.sorted { ($0 as! KubeCluster).name < ($1 as! KubeCluster).name }
            case .users:
                filtered = kubeUsers
                if !searchText.isEmpty {
                    filtered = kubeUsers.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
                }
                return filtered.sorted { ($0 as! KubeUser).name < ($1 as! KubeUser).name }
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
        // Or ensure messageHandler.show internally calls postMessage or updates appMessage
        // Current structure: messageHandler seems separate, let's unify
        self.messageHandler.messagePoster = { [weak self] message, type in
            Task { @MainActor in
                self?.postMessage(message, type: type)
            }
        } // Inject posting capability

        loadSshConfig()
        loadKubeConfig()
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
                    messageHandler.show(ConfigForgeConstants.SuccessMessages.configLoaded, type: .success)
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
                    throw NSError(domain: "MainViewModel", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "ViewModel已被释放"])
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
                messageHandler.show(ConfigForgeConstants.SuccessMessages.configSaved, type: .success)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    // 添加新条目
    func addSshEntry(host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            messageHandler.show(ConfigForgeConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        if sshEntries.contains(where: { $0.host == host }) {
            messageHandler.show(ConfigForgeConstants.ErrorMessages.duplicateHostError, type: .error)
            return
        }
        
        let newEntry = SSHConfigEntry(host: host, properties: properties)
        sshEntries.append(newEntry)
        safelySelectEntry(newEntry)
        messageHandler.show(ConfigForgeConstants.SuccessMessages.entryAdded, type: .success)
        saveSshConfig()
    }
    
    // 更新条目
    func updateSshEntry(id: UUID, host: String, properties: [String: String]) {
        guard !host.isEmpty else {
            messageHandler.show(ConfigForgeConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        if let index = sshEntries.firstIndex(where: { $0.id == id }) {
            let otherEntries = sshEntries.filter { $0.id != id }
            if otherEntries.contains(where: { $0.host == host }) {
                messageHandler.show(ConfigForgeConstants.ErrorMessages.duplicateHostError, type: .error)
                return
            }
            
            var updatedEntry = SSHConfigEntry(host: host, properties: properties)
            sshEntries[index] = updatedEntry
            safelySelectEntry(updatedEntry)
            messageHandler.show(ConfigForgeConstants.SuccessMessages.entryUpdated, type: .success)
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
            messageHandler.show(ConfigForgeConstants.SuccessMessages.entryDeleted, type: .success)
            saveSshConfig()
        }
    }
    
    // 备份配置
    func backupSshConfig(to url: URL) {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw NSError(domain: "MainViewModel", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "ViewModel已被释放"])
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
                messageHandler.show(ConfigForgeConstants.SuccessMessages.configBackedUp, type: .success)
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
            messageHandler.show(ConfigForgeConstants.SuccessMessages.configRestored, type: .success)
        case .failure(let error):
            ErrorHandler.handle(error, messageHandler: messageHandler)
            // Decide on behavior: clear entries, keep old ones, show specific error?
            // loadSshConfig() // Could reload the (potentially overwritten) file
        }
    }
    
    // 加载 Kubeconfig
    func loadKubeConfig() {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { 
                // 在闭包内创建实例
                let manager = KubeConfigFileManager()
                let loadResult = manager.loadConfig() // 不需要await，这不是异步方法
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
                self.kubeContexts = loadedConfig.safeContexts
                self.kubeClusters = loadedConfig.safeClusters
                self.kubeUsers = loadedConfig.safeUsers
                self.currentKubeContextName = loadedConfig.currentContext

                if !loadedConfig.safeContexts.isEmpty && selectedConfigurationType == .kubernetes {
                    messageHandler.show("Kubeconfig 加载成功", type: .success)
                }

            case .failure(let error):
                // Handle Kubeconfig specific errors gracefully
                // Use case matching instead of == comparison
                if case KubeConfigFileManagerError.configFileNotFound = error {
                    self.kubeConfig = KubeConfig(apiVersion: nil, kind: nil, clusters: [], contexts: [], users: [], currentContext: nil)
                    self.kubeContexts = []
                    self.kubeClusters = []
                    self.kubeUsers = []
                    self.currentKubeContextName = nil
                } else {
                    ErrorHandler.handle(error, messageHandler: messageHandler)
                    self.kubeConfig = nil
                    self.kubeContexts = []
                    self.kubeClusters = []
                    self.kubeUsers = []
                    self.currentKubeContextName = nil
                }
            }
        }
    }
    
    // MARK: - Kubernetes Specific Methods (Placeholders/Basic Impl)
    
    // Placeholder: Save current Kubernetes configuration
    func saveKubeConfig() {
        // Actual implementation will require formatting the kubeConfig object (if loaded)
        // and writing it using kubeConfigFileManager.
        Task {
            isLoading = true
            
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self, let config = await self.kubeConfig else { 
                    throw NSError(domain: "MainViewModel", code: -1, 
                                  userInfo: [NSLocalizedDescriptionKey: "KubeConfig未加载或已被释放"])
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
    
    // 设置当前 Kubeconfig Context
    func setCurrentKubeContext(name: String) {
        // Ensure kubeConfig exists and the context name is valid
        guard self.kubeConfig != nil else {
            messageHandler.show("无法设置当前 Context：Kubeconfig 数据未加载。", type: .error)
            return
        }

        guard self.kubeContexts.contains(where: { $0.name == name }) else {
            messageHandler.show("无法设置当前 Context：无效的 Context 名称 '\(name)'。", type: .error)
            return
        }

        // Avoid unnecessary save if the context is already the current one
        if self.kubeConfig?.currentContext == name {
            print("Context '\(name)' is already the current context.")
            return
        }

        // Update the model
        self.kubeConfig?.currentContext = name
        self.currentKubeContextName = name // Update the published property for UI reactivity

        // Save the changes
        saveKubeConfig()

        // Optionally show success message
        messageHandler.show("当前 Kubeconfig Context 已设置为 '\(name)'。", type: .success)
    }
    
    // 获取消息处理器（用于视图绑定）
    func getMessageHandler() -> MessageHandler {
        messageHandler
    }
    
    // 获取异步工具（用于视图绑定）
    func getAsyncUtility() -> AsyncUtility {
        asyncUtility
    }
    
    // Add/Update/Delete Kubeconfig items (Implementations needed later)
    // Placeholder Add Methods for Kube Objects
    func addKubeContext() {
        // 生成唯一的上下文名称
        let newName = generateUniqueName(base: "new-context", existing: kubeContexts.map { $0.name })
        
        // 确保至少有一个集群和用户
        guard let defaultCluster = kubeClusters.first?.name, let defaultUser = kubeUsers.first?.name else {
            messageHandler.show("无法添加 Context：需要至少一个 Cluster 和 User。", type: .error)
            return
        }
        
        // 创建新上下文
        let newContext = KubeContext(
            name: newName, 
            context: ContextDetails(
                cluster: defaultCluster, 
                user: defaultUser, 
                namespace: nil
            )
        )
        
        // 更新数据模型
        kubeContexts.append(newContext)
        kubeConfig?.contexts = kubeContexts
        
        // 选择新创建的上下文
        safelySelectEntry(newContext)
        
        // 保存配置
        messageHandler.show("已创建新 Context '\(newName)'。", type: .success)
        saveKubeConfig()
    }

    func addKubeCluster() {
        // 生成唯一的集群名称
        let newName = generateUniqueName(base: "new-cluster", existing: kubeClusters.map { $0.name })
        
        // 创建新集群
        let newCluster = KubeCluster(
            name: newName, 
            cluster: ClusterDetails(
                server: "https://kubernetes.default.svc", 
                certificateAuthorityData: nil, 
                insecureSkipTlsVerify: true
            )
        )
        
        // 更新数据模型
        kubeClusters.append(newCluster)
        kubeConfig?.clusters = kubeClusters
        
        // 选择新创建的集群
        safelySelectEntry(newCluster)
        
        // 保存配置
        messageHandler.show("已创建新 Cluster '\(newName)'。", type: .success)
        saveKubeConfig()
    }

    func addKubeUser() {
        // 生成唯一的用户名称
        let newName = generateUniqueName(base: "new-user", existing: kubeUsers.map { $0.name })
        
        // 创建新用户
        let newUser = KubeUser(
            name: newName, 
            user: UserDetails(
                clientCertificateData: nil, 
                clientKeyData: nil, 
                token: nil
            )
        )
        
        // 更新数据模型
        kubeUsers.append(newUser)
        kubeConfig?.users = kubeUsers
        
        // 选择新创建的用户
        safelySelectEntry(newUser)
        
        // 保存配置
        messageHandler.show("已创建新 User '\(newName)'。", type: .success)
        saveKubeConfig()
    }

    func updateKubeContext(id: String, name: String, cluster: String, user: String, namespace: String?) {
        guard !name.isEmpty, !cluster.isEmpty, !user.isEmpty else {
            messageHandler.show("Context 名称、Cluster 和 User 不能为空。", type: .error)
            return
        }
        
        // 检查名称唯一性（排除当前上下文）
        let otherContexts = kubeContexts.filter { $0.id != id }
        if otherContexts.contains(where: { $0.name == name }) {
            messageHandler.show("已存在相同名称的 Context '\(name)'。", type: .error)
            return
        }
        
        // 查找并更新上下文
        if let index = kubeContexts.firstIndex(where: { $0.id == id }) {
            kubeContexts[index].name = name
            kubeContexts[index].context.cluster = cluster
            kubeContexts[index].context.user = user
            kubeContexts[index].context.namespace = namespace
            
            // 更新 kubeConfig
            kubeConfig?.contexts = kubeContexts
            
            // 如果更新的是当前上下文，更新 currentKubeContextName
            if kubeConfig?.currentContext == id {
                kubeConfig?.currentContext = name
                currentKubeContextName = name
            }
            
            // 保存配置
            messageHandler.show("Context '\(name)' 已更新。", type: .success)
            saveKubeConfig()
            
            // 重新选择更新后的对象，确保视图刷新
            let updatedContext = kubeContexts[index]
            safelySelectEntry(nil) // 先取消选择
            updateUIState {
                // 在下一个运行循环中重新选择，确保 UI 有机会更新
                self.safelySelectEntry(updatedContext)
            }
        }
    }

    func updateKubeCluster(id: String, name: String, server: String, certificateAuthorityData: String?, insecureSkipTlsVerify: Bool?) {
        guard !name.isEmpty, !server.isEmpty else {
            messageHandler.show("Cluster 名称和服务器 URL 不能为空。", type: .error)
            return
        }
        
        // 检查名称唯一性（排除当前集群）
        let otherClusters = kubeClusters.filter { $0.id != id }
        if otherClusters.contains(where: { $0.name == name }) {
            messageHandler.show("已存在相同名称的 Cluster '\(name)'。", type: .error)
            return
        }
        
        // 查找并更新集群
        if let index = kubeClusters.firstIndex(where: { $0.id == id }) {
            // 保存旧名称以处理依赖关系
            let oldName = kubeClusters[index].name
            
            // 更新集群
            kubeClusters[index].name = name
            kubeClusters[index].cluster.server = server
            kubeClusters[index].cluster.certificateAuthorityData = certificateAuthorityData
            kubeClusters[index].cluster.insecureSkipTlsVerify = insecureSkipTlsVerify
            
            // 更新 kubeConfig
            kubeConfig?.clusters = kubeClusters
            
            // 如果集群名称已更改，更新所有引用该集群的上下文
            if oldName != name {
                for i in 0..<kubeContexts.count {
                    if kubeContexts[i].context.cluster == oldName {
                        kubeContexts[i].context.cluster = name
                    }
                }
                kubeConfig?.contexts = kubeContexts
            }
            
            // 保存配置
            messageHandler.show("Cluster '\(name)' 已更新。", type: .success)
            saveKubeConfig()
            
            // 重新选择更新后的对象，确保视图刷新
            let updatedCluster = kubeClusters[index]
            safelySelectEntry(nil) // 先取消选择
            updateUIState {
                // 在下一个运行循环中重新选择，确保 UI 有机会更新
                self.safelySelectEntry(updatedCluster)
            }
        }
    }

    func updateKubeUser(id: String, name: String, clientCertificateData: String?, clientKeyData: String?, token: String?) {
        guard !name.isEmpty else {
            messageHandler.show("User 名称不能为空。", type: .error)
            return
        }
        
        // 检查名称唯一性（排除当前用户）
        let otherUsers = kubeUsers.filter { $0.id != id }
        if otherUsers.contains(where: { $0.name == name }) {
            messageHandler.show("已存在相同名称的 User '\(name)'。", type: .error)
            return
        }
        
        // 查找并更新用户
        if let index = kubeUsers.firstIndex(where: { $0.id == id }) {
            // 保存旧名称以处理依赖关系
            let oldName = kubeUsers[index].name
            
            // 更新用户
            kubeUsers[index].name = name
            kubeUsers[index].user.clientCertificateData = clientCertificateData
            kubeUsers[index].user.clientKeyData = clientKeyData
            kubeUsers[index].user.token = token
            
            // 更新 kubeConfig
            kubeConfig?.users = kubeUsers
            
            // 如果用户名称已更改，更新所有引用该用户的上下文
            if oldName != name {
                for i in 0..<kubeContexts.count {
                    if kubeContexts[i].context.user == oldName {
                        kubeContexts[i].context.user = name
                    }
                }
                kubeConfig?.contexts = kubeContexts
            }
            
            // 保存配置
            messageHandler.show("User '\(name)' 已更新。", type: .success)
            saveKubeConfig()
            
            // 重新选择更新后的对象，确保视图刷新
            let updatedUser = kubeUsers[index]
            safelySelectEntry(nil) // 先取消选择
            updateUIState {
                // 在下一个运行循环中重新选择，确保 UI 有机会更新
                self.safelySelectEntry(updatedUser)
            }
        }
    }

    // 辅助方法：生成唯一名称
    private func generateUniqueName(base: String, existing: [String]) -> String {
        var counter = 1
        var newName = "\(base)-\(counter)"
        
        while existing.contains(newName) {
            counter += 1
            newName = "\(base)-\(counter)"
        }
        
        return newName
    }

    func deleteKubeContext(id: String) {
        if let index = kubeContexts.firstIndex(where: { $0.id == id }) {
            let contextToDelete = kubeContexts[index]
            kubeContexts.remove(at: index)
            kubeConfig?.contexts = kubeContexts // Update main config object

            // Deselect if the deleted item was selected
            if let selected = selectedEntry as? KubeContext, selected.id == id {
                safelySelectEntry(nil)
            }

            messageHandler.show("Context '\(contextToDelete.name)' 已删除。", type: .success)
            saveKubeConfig()
        }
    }

    // func addKubeCluster(...) { ... } // Moved up
    // func updateKubeCluster(...) { ... }

    func deleteKubeCluster(id: String) {
        // Dependency Check: Find contexts using this cluster
        let dependingContexts = kubeContexts.filter { $0.context.cluster == id }

        if !dependingContexts.isEmpty {
            let contextNames = dependingContexts.map { $0.name }.joined(separator: ", ")
            messageHandler.show("无法删除 Cluster '\(id)'，因为它被 Context(s): \(contextNames) 使用。", type: .error)
            return
        }

        // Proceed with deletion if no dependencies
        if let index = kubeClusters.firstIndex(where: { $0.id == id }) {
            let clusterToDelete = kubeClusters[index]
            kubeClusters.remove(at: index)
            kubeConfig?.clusters = kubeClusters // Update main config object

            if let selected = selectedEntry as? KubeCluster, selected.id == id {
                safelySelectEntry(nil)
            }

            messageHandler.show("Cluster '\(clusterToDelete.name)' 已删除。", type: .success)
            saveKubeConfig()
        }
    }

    // func addKubeUser(...) { ... } // Moved up
    // func updateUser(...) { ... }

    func deleteKubeUser(id: String) {
        // Dependency Check: Find contexts using this user
        let dependingContexts = kubeContexts.filter { $0.context.user == id }

        if !dependingContexts.isEmpty {
            let contextNames = dependingContexts.map { $0.name }.joined(separator: ", ")
            messageHandler.show("无法删除 User '\(id)'，因为它被 Context(s): \(contextNames) 使用。", type: .error)
            return
        }

        // Proceed with deletion if no dependencies
        if let index = kubeUsers.firstIndex(where: { $0.id == id }) {
            let userToDelete = kubeUsers[index]
            kubeUsers.remove(at: index)
            kubeConfig?.users = kubeUsers // Update main config object

            if let selected = selectedEntry as? KubeUser, selected.id == id {
                safelySelectEntry(nil)
            }

            messageHandler.show("User '\(userToDelete.name)' 已删除。", type: .success)
            saveKubeConfig()
        }
    }

    // MARK: - Public Methods - Kubeconfig Backup/Restore

    // IMPLEMENT the async backup function that takes a URL
    func backupKubeConfig(to url: URL) {
        Task {
            guard let config = self.kubeConfig else {
                messageHandler.show("错误：无法备份，KubeConfig 未加载。", type: .error)
                return
            }
            
            isLoading = true
            let result = await asyncUtility.perform { 
                // 在闭包内创建实例
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

    // RE-INSERT the restoreKubeConfig function that was accidentally removed
    // Restore Kubeconfig (Placeholder Implementation)
    func restoreKubeConfig(from url: URL) async {
        isLoading = true
        let result = await asyncUtility.perform { 
            // 在闭包内创建实例
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
            self.kubeContexts = restoredConfig.safeContexts
            self.kubeClusters = restoredConfig.safeClusters
            self.kubeUsers = restoredConfig.safeUsers
            self.currentKubeContextName = restoredConfig.currentContext
            
            // 选择第一个上下文（如果有）
            if let firstContext = self.kubeContexts.first {
                safelySelectEntry(firstContext)
            } else {
                safelySelectEntry(nil)
            }
            
            messageHandler.show("Kubeconfig 已从 \(url.lastPathComponent) 成功恢复。", type: .success)
        case .failure(let error):
            messageHandler.show("恢复 Kubeconfig 失败：\(error.localizedDescription)", type: .error)
            // 重新加载现有配置
            loadKubeConfig()
        }
        
        isLoading = false
    }
    
    // MARK: - Unified Save/Backup/Restore
    
    func saveCurrentConfig() {
        switch selectedConfigurationType {
        case .ssh:
            saveSshConfig() // Call existing SSH save method
        case .kubernetes:
            saveKubeConfig() // Call new Kube save method (placeholder for now)
        }
    }
    
    // Note: Backup is primarily handled by the ConfigDocument formatting
    //       and the .fileExporter modifier in ContentView.
    //       This method isn't strictly necessary unless pre-processing is needed.
    // func backupCurrentConfig(to url: URL) { ... }

    func restoreCurrentConfig(from url: URL) {
        Task {
            isLoading = true
            print("--- Triggered: restoreCurrentConfig for type: \(selectedConfigurationType) from URL: \(url.path) ---")
            // Determine type based on the **currently selected view** in the UI,
            // as the ConfigDocument init tries to guess but might be ambiguous.
            // A more robust solution might involve asking the user or better file inspection.
            switch selectedConfigurationType {
            case .ssh:
                await restoreSshConfig(from: url)
            case .kubernetes:
                await restoreKubeConfig(from: url)
            }
            isLoading = false
        }
    }
    
    // MARK: - Helper Methods (Existing)
    // ... existing code ...

    // MARK: - Kubernetes Navigation Helpers

    // Handle changing between context/cluster/user views
    private func handleKubeObjectTypeChange(from oldType: KubeObjectType, to newType: KubeObjectType) {
        // If we're currently editing, check if we need to save
        if isEditing {
            // In a real app, we would show a dialog here to ask user to save
            // Since we can't directly show alerts from the ViewModel, we can:
            // 1. Revert the selection (let the View handle the alert)
            // 2. Auto-save the changes (less ideal)
            // 3. Define a callback that the View can use to handle this situation
            
            // For now, auto-save if editing
            saveKubeConfig()
            isEditing = false
        }
        
        // Select the first item of the new type, if available
        switch newType {
        case .contexts:
            if let firstContext = kubeContexts.first {
                safelySelectEntry(firstContext)
            } else {
                safelySelectEntry(nil) // No contexts available
            }
        case .clusters:
            if let firstCluster = kubeClusters.first {
                safelySelectEntry(firstCluster)
            } else {
                safelySelectEntry(nil) // No clusters available
            }
        case .users:
            if let firstUser = kubeUsers.first {
                safelySelectEntry(firstUser)
            } else {
                safelySelectEntry(nil) // No users available
            }
        }
    }
}
