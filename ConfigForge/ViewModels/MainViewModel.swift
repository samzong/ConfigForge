//
//  MainViewModel.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI
import Combine
import Foundation
import AppKit
import Yams


enum ConfigType: String, CaseIterable, Identifiable {
    case ssh = "SSH"
    case kubernetes = "Kubernetes"
    var id: String { rawValue }
}

@MainActor
class MainViewModel: ObservableObject {
    @Published var selectedConfigurationType: ConfigType = .ssh
    @Published var searchText: String = ""
    @Published var configSearchText: String = ""
    @Published var selectedEntry: (any Identifiable)?
    @Published var selectedConfigFile: KubeConfigFile?
    @Published var isEditing: Bool = false
    @Published var errorMessage: String?
    @Published var appMessage: AppMessage?
    @Published var isLoading: Bool = false
    @Published var isLoadingConfigFiles: Bool = false
    
    @Published var sshEntries: [SSHConfigEntry] = []
    @Published var activeConfigContent: String = ""
    
    @Published var configFiles: [KubeConfigFile] = []
    @Published var selectedConfigFileContent: String = ""
    
    private let asyncUtility = AsyncUtility()
    private let messageHandler = MessageHandler()
    private let sshFileManager = SSHConfigFileManager()
    private let kubeConfigFileManager = KubeConfigFileManager()
    let sshParser = SSHConfigParser()
    
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
    
    @MainActor
    func updateUIState(action: @escaping () -> Void) {
        action()
    }
    
    func postMessage(_ message: String, type: MessageType) {
        updateUIState {
            self.appMessage = AppMessage(type: type, message: message)
        }
    }
    
    init() {
        messageHandler.messagePoster = { [weak self] message, type in
            Task { @MainActor in
                self?.postMessage(message, type: type)
            }
        }

        loadSshConfig()
        loadKubeConfig()
        loadKubeConfigFiles()
        setupEventHandling()
    }
    
    func safelySelectEntry(_ entry: (any Identifiable)?) {
        Task {
            if isEditing {
                await MainActor.run { isEditing = false }
            }
            try? await Task.sleep(nanoseconds: UInt64(0.05 * 1_000_000_000))
            await MainActor.run { selectedEntry = entry }
        }
    }
    
    func loadSshConfig() {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { [sshFileManager, sshParser] in
                let content = try await sshFileManager.readConfigFile()
                return await Task.detached {
                    return sshParser.parseConfig(content: content)
                }.value
            }
            isLoading = false
            
            switch result {
            case .success(let parsedEntries):
                self.sshEntries = parsedEntries
                if !parsedEntries.isEmpty && selectedConfigurationType == .ssh {
                    messageHandler.show(MessageConstants.SuccessMessages.configLoaded, type: .success, priority: .low)
                }
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
                sshEntries = []
            }
        }
    }
    
    func saveSshConfig() {
        Task {
            guard selectedConfigurationType == .ssh else { return }
            isLoading = true
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw ConfigForgeError.unknown("ViewModel has been released")
                }
                let formattedContent = await Task.detached { [entries = self.sshEntries, parser = self.sshParser] in
                    return parser.formatConfig(entries: entries)
                }.value
                try await sshFileManager.writeConfigFile(content: formattedContent)
                return ()
            }
            
            isLoading = false
            switch result {
            case .success:
                messageHandler.show(MessageConstants.SuccessMessages.configSaved, type: .success, priority: .low)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
            }
        }
    }
    
    func addSshEntry(host: String, directives: [(key: String, value: String)]) {
        guard !host.isEmpty else {
            messageHandler.show(MessageConstants.ErrorMessages.emptyHostError, type: .error)
            return
        }
        
        if sshEntries.contains(where: { $0.host == host }) {
            messageHandler.show(MessageConstants.ErrorMessages.duplicateHostError, type: .error)
            return
        }
        
        let newEntry = SSHConfigEntry(host: host, directives: directives)
        sshEntries.append(newEntry)
        safelySelectEntry(newEntry)
        messageHandler.show(MessageConstants.SuccessMessages.entryAdded, type: .success, priority: .low)
        saveSshConfig()
    }
    
    func updateSshEntry(id: UUID, host: String, directives: [(key: String, value: String)]) {
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
            
            // Preserve the ID by creating a new entry with the existing ID
            var updatedEntry = SSHConfigEntry(id: id, host: host, directives: directives)
            sshEntries[index] = updatedEntry
            safelySelectEntry(updatedEntry)
            messageHandler.show(MessageConstants.SuccessMessages.entryUpdated, type: .success, priority: .low)
            saveSshConfig()
        }
    }
    
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
    
    func backupSshConfig(to url: URL) {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { [weak self] in
                guard let self = self else { 
                    throw ConfigForgeError.unknown("ViewModel has been released")
                }
                let content = await Task.detached { [entries = self.sshEntries, parser = self.sshParser] in
                    return parser.formatConfig(entries: entries)
                }.value
                try await sshFileManager.backupConfigFile(content: content, to: url)
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
    
    func restoreSshConfig(from url: URL) async {
        isLoading = true
        let result = await asyncUtility.perform { [sshFileManager, sshParser] in
            let content = try String(contentsOf: url, encoding: .utf8)
            let parsedEntries = await Task.detached {
                return sshParser.parseConfig(content: content)
            }.value
            try await sshFileManager.writeConfigFile(content: content)
            return parsedEntries
        }

        switch result {
        case .success(let parsedEntries):
            sshEntries = parsedEntries
            safelySelectEntry(sshEntries.first)
            messageHandler.show(MessageConstants.SuccessMessages.configRestored, type: .success)
        case .failure(let error):
            ErrorHandler.handle(error, messageHandler: messageHandler)
        }
    }
    
    func loadKubeConfig() {
        Task {
            isLoading = true
            let result = await asyncUtility.perform { 
                let manager = KubeConfigFileManager()
                let loadResult = manager.loadConfig()
                switch loadResult {
                case .success(let yamlContent):
                    return yamlContent 
                case .failure(let error):
                    throw error
                }
            }
            isLoading = false

            switch result {
            case .success(let yamlContent):
                self.activeConfigContent = yamlContent
                
                if let mainIndex = configFiles.firstIndex(where: { $0.fileType == .main }) {
                    var updatedMainConfig = configFiles[mainIndex]
                    updatedMainConfig.updateYamlContent(yamlContent)
                    configFiles[mainIndex] = updatedMainConfig
                }

                if selectedConfigurationType == .kubernetes {
                    messageHandler.show("Kubeconfig loaded successfully", type: .success)
                }

            case .failure(let error):
                if case ConfigForgeError.kubeConfigNotFound = error {
                    self.activeConfigContent = ""
                } else {
                    ErrorHandler.handle(error, messageHandler: messageHandler)
                    self.activeConfigContent = ""
                }
            }
        }
    }
    
    func loadKubeConfigFiles() {
        Task {
            isLoadingConfigFiles = true
            
            let result = await asyncUtility.perform {
                let fileManager = KubeConfigFileManager()
                let discoverResult = await fileManager.discoverConfigFiles()
                
                switch discoverResult {
                case .success(let files):
                    let validatedFiles = await self.validateConfigFiles(files)
                    return validatedFiles
                case .failure(let error):
                    throw error
                }
            }
            
            isLoadingConfigFiles = false
            
            switch result {
            case .success(let files):
                var finalFiles = files
                if let mainConfig = createMainConfigFileEntry() {
                    finalFiles.insert(mainConfig, at: 0)
                }
                self.configFiles = finalFiles
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: messageHandler)
                self.configFiles = []
            }
        }
    }
    
    private func validateConfigFiles(_ files: [KubeConfigFile]) async -> [KubeConfigFile] {
        var validatedFiles = [KubeConfigFile]()
        
        for var configFile in files {
            if let yamlContent = configFile.yamlContent {
                let validationResult = await validateYamlContent(yamlContent)
                
                switch validationResult {
                case .success:
                    configFile.status = .valid
                case .failure(let error):
                    configFile.markAsInvalid(error.localizedDescription)
                }
            } else {
                configFile.markAsInvalid("Config file content is empty or cannot be read")
            }
            
            validatedFiles.append(configFile)
        }
        
        return validatedFiles
    }
    
    private func createMainConfigFileEntry() -> KubeConfigFile? {
        do {
            let mainPath = try kubeConfigFileManager.getConfigFilePath()
            guard FileManager.default.fileExists(atPath: mainPath.path),
                  !activeConfigContent.isEmpty else {
                return nil
            }
            
            return KubeConfigFile(
                fileName: "config",
                filePath: mainPath,
                fileType: .main,
                yamlContent: activeConfigContent,
                creationDate: nil,
                modificationDate: nil,
                isActive: false
            )
        } catch {
            return nil
        }
    }
    
    private func validateYamlContent(_ content: String) async -> Result<Void, ConfigForgeError> {
        do {
            guard let yaml = try Yams.load(yaml: content) as? [String: Any] else {
                return .failure(.validation("YAML format error: cannot parse to dictionary"))
            }
            
            guard let clusters = yaml["clusters"] as? [[String: Any]], !clusters.isEmpty else {
                return .failure(.validation("Config missing cluster definition"))
            }
            
            guard let contexts = yaml["contexts"] as? [[String: Any]], !contexts.isEmpty else {
                return .failure(.validation("Config missing context definition"))
            }
            
            guard let users = yaml["users"] as? [[String: Any]], !users.isEmpty else {
                return .failure(.validation("Config missing user definition"))
            }
            
            if let currentContext = yaml["current-context"] as? String {
                let contextExists = contexts.contains { context in
                    if let contextName = (context["name"] as? String) {
                        return contextName == currentContext
                    }
                    return false
                }
                
                if !contextExists {
                    return .failure(.validation("Current context '\(currentContext)' is not defined in config"))
                }
            }
            
            for context in contexts {
                guard let name = context["name"] as? String,
                      let contextDict = context["context"] as? [String: Any],
                      let clusterName = contextDict["cluster"] as? String,
                      let userName = contextDict["user"] as? String else {
                    return .failure(.validation("Context definition format error"))
                }
                
                let clusterExists = clusters.contains { cluster in
                    if let clusterNameInList = cluster["name"] as? String {
                        return clusterNameInList == clusterName
                    }
                    return false
                }
                
                if !clusterExists {
                    return .failure(.validation("Context '\(name)' references undefined cluster '\(clusterName)'"))
                }
                
                let userExists = users.contains { user in
                    if let userNameInList = user["name"] as? String {
                        return userNameInList == userName
                    }
                    return false
                }
                
                if !userExists {
                    return .failure(.validation("Context '\(name)' references undefined user '\(userName)'"))
                }
            }
            
            return .success(())
        } catch {
            return .failure(.validation("YAML parsing error: \\(error.localizedDescription)"))
        }
    }
    
    func refreshKubeConfigFiles() {
        loadKubeConfigFiles()
    }
    
    func selectConfigFile(_ configFile: KubeConfigFile) {
        selectedConfigFile = configFile
        
        Task {
            do {
                let fileContent = try String(contentsOf: configFile.filePath, encoding: .utf8)
                await MainActor.run {
                    self.selectedConfigFileContent = fileContent
                }
            } catch {
                messageHandler.show("Cannot read config file content: \(error.localizedDescription)", type: .error)
                await MainActor.run {
                    self.selectedConfigFileContent = "# Cannot read file content\n# \(error.localizedDescription)"
                }
            }
        }
    }

    func saveConfigFileContent(_ content: String) async {
        guard let configFile = selectedConfigFile else { return }
        guard configFile.fileType != .main else {
            messageHandler.show("Cannot save main config file", type: .error)
            return
        }
        
        let fileWatcher = EventManager.shared.getFileWatcher()
        let success = fileWatcher.createOrUpdateFile(content: content, at: configFile.filePath)
        
        if success {
            let validationResult = await validateYamlContent(content)
            
            var updatedFile = configFile
            updatedFile.updateYamlContent(content)
            
            switch validationResult {
            case .success:
                updatedFile.status = .valid
            case .failure(let error):
                updatedFile.markAsInvalid(error.localizedDescription)
            }
            
            await MainActor.run {
                if let index = configFiles.firstIndex(where: { $0.id == configFile.id }) {
                    configFiles[index] = updatedFile
                }
                
                selectedConfigFile = updatedFile
                selectedConfigFileContent = content
                
                if updatedFile.status == .valid {
                    messageHandler.show("Config saved", type: .success, priority: .low)
                } else {
                    messageHandler.show("Config saved, but validation failed: \(updatedFile.status)", type: .error)
                }
            }
            
            if configFile.fileType == .active {
                loadKubeConfig()
            }
        } else {
            messageHandler.show("Failed to save config", type: .error)
        }
    }
    
    func activateConfigFile(_ configFile: KubeConfigFile) {
        guard configFile.fileType != .main else {
            messageHandler.show("Cannot activate main config file", type: .error)
            return
        }
        
        guard configFile.status == .valid else {
            messageHandler.show("Cannot activate invalid config file", type: .error)
            return
        }
        
        guard let yamlContent = configFile.yamlContent else {
            messageHandler.show("Cannot read config file content", type: .error)
            return
        }
        
        Task {
            isLoading = true
            
            do {
                let fileManager = KubeConfigFileManager()
                let mainConfigPath = try fileManager.getConfigFilePath()
                
                let fileWatcher = EventManager.shared.getFileWatcher()
                let success = fileWatcher.createOrUpdateFile(content: yamlContent, at: mainConfigPath)
                
                if success {
                    loadKubeConfig()
                    loadKubeConfigFiles()
                    
                    messageHandler.show("\(configFile.displayName) is now active config", type: .success)
                } else {
                    messageHandler.show("Failed to set active config", type: .error)
                }
            } catch {
                messageHandler.show("Failed to set active config: \(error.localizedDescription)", type: .error)
            }
            
            isLoading = false
        }
    }
    
    func promptForRenameConfigFile(_ configFile: KubeConfigFile) {
        let alert = NSAlert()
        alert.messageText = "Rename config file"
        alert.informativeText = "Please enter a new file name:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "New file name"
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
    
    func renameConfigFile(_ configFile: KubeConfigFile, to newName: String) {
        guard configFile.fileType != .main else {
            messageHandler.show("Cannot rename main config file", type: .error)
            return
        }
        
        guard !newName.isEmpty else {
            messageHandler.show("File name cannot be empty", type: .error)
            return
        }
        
        do {
            let fileManager = KubeConfigFileManager()
            let configsDir = try fileManager.getConfigsDirectoryPath()

            var newFileName = newName
            if !newFileName.hasSuffix(".yaml") && !newFileName.hasSuffix(".yml") {
                newFileName += ".yaml"
            }
            
            let newFilePath = configsDir.appendingPathComponent(newFileName)
            
            if FileManager.default.fileExists(atPath: newFilePath.path) {
                messageHandler.show("\(newFileName) already exists", type: .error)
                return
            }
            
            let oldFilePath = configFile.filePath
            
            let fileWatcher = EventManager.shared.getFileWatcher()
            let success = fileWatcher.renameFile(from: oldFilePath, to: newFilePath)
            
            if success {
                if selectedConfigFile?.id == configFile.id {
                    selectedConfigFile = nil
                    selectedConfigFileContent = ""
                }
                
                configFiles.removeAll(where: { $0.id == configFile.id })
                
                messageHandler.show("File renamed to \(newFileName)", type: .success)
                
                loadKubeConfigFiles()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    
                    if let newFile = configFiles.first(where: { $0.filePath.path == newFilePath.path }) {
                        selectConfigFile(newFile)
                    }
                }
            } else {
                messageHandler.show("Failed to rename file", type: .error)
            }
        } catch {
            messageHandler.show("Failed to rename file: \(error.localizedDescription)", type: .error)
        }
    }
    
    func promptForDeleteConfigFile(_ configFile: KubeConfigFile) {
        let alert = NSAlert()
        alert.messageText = "Delete config file"
        alert.informativeText = "Are you sure you want to delete \(configFile.displayName)? This action cannot be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Delete")
        alert.addButton(withTitle: "Cancel")
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            deleteConfigFile(configFile)
        }
    }
    
    func deleteConfigFile(_ configFile: KubeConfigFile) {
        guard configFile.fileType != .main else {
            messageHandler.show("Cannot delete main config file", type: .error)
            return
        }
        
        if selectedConfigFile?.id == configFile.id {
            selectedConfigFile = nil
            selectedConfigFileContent = ""
        }

        let fileWatcher = EventManager.shared.getFileWatcher()
        let success = fileWatcher.deleteFile(at: configFile.filePath)
        
        if success {
            messageHandler.show("\(configFile.displayName) deleted", type: .success)
            
            if let index = configFiles.firstIndex(where: { $0.id == configFile.id }) {
                configFiles.remove(at: index)
            }
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                guard let self = self else { return }
                loadKubeConfigFiles()
            }
        } else {
            messageHandler.show("Failed to delete file", type: .error)
        }
    }
    
    func createNewConfigFile() {
        Task {
            do {
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
                
                let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                    .replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: ":", with: "-")
                    .replacingOccurrences(of: " ", with: "_")
                
                let newFileName = "new-config-\(timestamp).yaml"
                
                let fileManager = KubeConfigFileManager()
                let configsDir = try fileManager.getConfigsDirectoryPath()
                let newFilePath = configsDir.appendingPathComponent(newFileName)
                
                let fileWatcher = EventManager.shared.getFileWatcher()
                let success = fileWatcher.createOrUpdateFile(content: emptyConfig, at: newFilePath)
                
                if success {
                    loadKubeConfigFiles()
                    
                    try await Task.sleep(nanoseconds: 500_000_000) // 500 ms
                    
                    if let newFile = configFiles.first(where: { $0.filePath.path == newFilePath.path }) {
                        selectConfigFile(newFile)
                        messageHandler.show("New config file created", type: .success)
                    } else {
                        loadKubeConfigFiles()
                        messageHandler.show("New config file created, please select it in the list", type: .success)
                    }
                } else {
                    messageHandler.show("Failed to create new config file", type: .error)
                }
            } catch {
                messageHandler.show("Failed to create new config file: \(error.localizedDescription)", type: .error)
            }
        }
    }
    
    func promptForCopyConfigFile(_ configFile: KubeConfigFile) {
        let alert = NSAlert()
        alert.messageText = "Copy config file"
        alert.informativeText = "Please enter a new file name:"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.addButton(withTitle: "Cancel")
        
        let textField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        textField.placeholderString = "New file name"
        textField.stringValue = "copy-of-\(configFile.displayName)"
        
        alert.accessoryView = textField
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let newName = textField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            if !newName.isEmpty {
                copyConfigFile(configFile, to: newName)
            }
        }
    }
    
    func copyConfigFile(_ configFile: KubeConfigFile, to newName: String) {
        guard configFile.fileType != .main else {
            messageHandler.show("Cannot copy main config file", type: .error)
            return
        }
        
        do {
            let fileManager = KubeConfigFileManager()
            let configsDir = try fileManager.getConfigsDirectoryPath()
            
            var newFileName = newName
            if !newFileName.hasSuffix(".yaml") && !newFileName.hasSuffix(".yml") {
                newFileName += ".yaml"
            }
            
            let fileWatcher = EventManager.shared.getFileWatcher()
            let success = fileWatcher.copyFile(from: configFile.filePath, to: configsDir, newFileName: newFileName)
            
            if success {
                messageHandler.show("File copied to \(newFileName)", type: .success)
                
                loadKubeConfigFiles()
                
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                    guard let self = self else { return }
                    
                    let newFilePath = configsDir.appendingPathComponent(newFileName)
                    if let newFile = configFiles.first(where: { $0.filePath.path == newFilePath.path }) {
                        selectConfigFile(newFile)
                    }
                }
            } else {
                messageHandler.show("Failed to copy file", type: .error)
            }
        } catch {
            messageHandler.show("Failed to copy file: \(error.localizedDescription)", type: .error)
        }
    }
    

    func getMessageHandler() -> MessageHandler {
        messageHandler
    }
    
    func getAsyncUtility() -> AsyncUtility {
        asyncUtility
    }
    
    func saveCurrentConfig() {
        switch selectedConfigurationType {
        case .ssh:
            saveSshConfig()
        case .kubernetes:
            saveKubeConfig()
        }
    }
    
    func saveKubeConfig() {
        Task {
            isLoading = true
            
            guard !activeConfigContent.isEmpty else { 
                messageHandler.show("KubeConfig is empty", type: .error)
                isLoading = false
                return
            }
            
            do {
                let fileManager = KubeConfigFileManager()
                let configPath = try fileManager.getConfigFilePath()
                
                let fileWatcher = EventManager.shared.getFileWatcher()
                let success = fileWatcher.createOrUpdateFile(content: activeConfigContent, at: configPath)
                
                if success {
                    await MainActor.run {
                        self.isEditing = false
                    }
                    
                    messageHandler.show("Kubeconfig saved", type: .success)
                    
                    EventManager.shared.notifyActiveConfigChanged(activeConfigContent)
                } else {
                    messageHandler.show("Failed to save Kubeconfig", type: .error)
                }
            } catch {
                messageHandler.show("Failed to save Kubeconfig: \(error.localizedDescription)", type: .error)
            }
            
            isLoading = false
        }
    }
    
    func backupKubeConfig(to url: URL) {
        Task {
            guard !activeConfigContent.isEmpty else {
                messageHandler.show("Failed to backup, KubeConfig is empty", type: .error)
                return
            }
            
            isLoading = true
            
            let fileWatcher = EventManager.shared.getFileWatcher()
            let success = fileWatcher.createOrUpdateFile(content: activeConfigContent, at: url)
            
            isLoading = false
            
            if success {
                messageHandler.show("Kubeconfig backuped to \(url.lastPathComponent)", type: .success)
            } else {
                messageHandler.show("Failed to backup Kubeconfig", type: .error)
            }
        }
    }

    func restoreKubeConfig(from url: URL) async {
        isLoading = true
        
        do {
            let backupContent = try String(contentsOf: url, encoding: .utf8)
            
            let fileManager = KubeConfigFileManager()
            let mainConfigPath = try fileManager.getConfigFilePath()
            
            let fileWatcher = EventManager.shared.getFileWatcher()
            let success = fileWatcher.createOrUpdateFile(content: backupContent, at: mainConfigPath)
            
            if success {
                activeConfigContent = backupContent
                messageHandler.show("Kubeconfig restored from \(url.lastPathComponent)", type: .success)
            } else {
                messageHandler.show("Failed to restore Kubeconfig", type: .error)
                loadKubeConfig()
            }
        } catch {
            messageHandler.show("Failed to restore Kubeconfig: \(error.localizedDescription)", type: .error)
            loadKubeConfig()
        }
        
        isLoading = false
    }
    
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
    
    private func setupEventHandling() {
        startFileWatching()
        
        EventManager.shared.events
            .receive(on: RunLoop.main)
            .sink { [weak self] event in
                guard let self = self else { return }
                
                switch event {
                case .configFileAdded(let url):
                    Task { @MainActor in
                        await self.reloadConfigFileByURL(url)
                    }
                    
                case .configFileChanged(let url):
                    Task { @MainActor in
                        await self.reloadConfigFileByURL(url)
                    }
                    
                case .configFileRemoved(let url):
                    Task { @MainActor in
                        self.removeConfigFile(url)
                    }
                    
                case .activeConfigChanged(let yamlContent):
                    Task { @MainActor in
                        self.activeConfigContent = yamlContent
                    }
                    
                case .reloadConfigRequested:
                    loadKubeConfigFiles()
                    
                case .notification(let message, let type):
                    messageHandler.show(message, type: type)
                }
            }
            .store(in: &cancellables)
    }

    private func startFileWatching() {
        _ = EventManager.shared.startWatchingConfigDirectory()
        _ = EventManager.shared.startWatchingMainConfig()
    }

    private func loadConfigFile(at url: URL) async throws -> KubeConfigFile {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ConfigForgeError.fileAccess("File does not exist")
        }
        
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
        
        guard var configFile = KubeConfigFile.from(url: url, fileType: fileType) else {
            throw ConfigForgeError.unknown("Failed to create config file object")
        }
        
        if let yamlContent = configFile.yamlContent {
            let validationResult = await validateYamlContent(yamlContent)
            
            switch validationResult {
            case .success:
                configFile.status = .valid
            case .failure(let error):
                configFile.markAsInvalid(error.localizedDescription)
            }
        } else {
            configFile.markAsInvalid("Failed to read file content")
        }
        
        return configFile
    }

    private func reloadConfigFileByURL(_ url: URL) async {
        if let index = configFiles.firstIndex(where: { $0.filePath == url }) {
            do {
                let updatedFile = try await loadConfigFile(at: url)
                configFiles[index] = updatedFile
                
                if selectedConfigFile?.filePath == url {
                    selectedConfigFile = updatedFile
                    do {
                        let content = try String(contentsOf: url, encoding: .utf8)
                        selectedConfigFileContent = content
                    } catch {
                        print("Failed to read file content: \(error.localizedDescription)")
                    }
                }
                
                if updatedFile.fileType == .active {
                    loadKubeConfig()
                }
            } catch {
                print("Failed to update config file: \(error.localizedDescription)")
            }
        } else {
            loadKubeConfigFiles()
        }
    }

    private func removeConfigFile(_ url: URL) {
        if let index = configFiles.firstIndex(where: { $0.filePath == url }) {
            if selectedConfigFile?.filePath == url {
                selectedConfigFile = nil
                selectedConfigFileContent = ""
            }
            
            configFiles.remove(at: index)
        }
    }

    private var cancellables = Set<AnyCancellable>()
}
