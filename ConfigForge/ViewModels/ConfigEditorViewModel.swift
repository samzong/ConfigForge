import SwiftUI
import Combine
import Foundation
import Yams

@MainActor
class ConfigEditorViewModel: ObservableObject {
    @Published var configFile: KubeConfigFile?
    @Published var editorContent: String = ""
    @Published var isEditing: Bool = false
    @Published var hasUnsavedChanges: Bool = false
    @Published var errorMessage: String?
    @Published var validationState: ValidationState = .notValidated

    private var undoStack: [String] = []
    private var redoStack: [String] = []
    private let maxUndoHistory: Int = 50
    private let messageHandler: MessageHandler
    private var validationTimer: Timer?
        
    init(messageHandler: MessageHandler = MessageHandler()) {
        self.messageHandler = messageHandler
    }
    
    func loadConfigFile(_ configFile: KubeConfigFile) {
        Task {
            do {
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
                    self.errorMessage = "Unable to load config file: \(error.localizedDescription)"
                    self.messageHandler.show("Unable to load config file", type: .error)
                }
            }
        }
    }
    
    func startEditing() {
        if !isEditing {
            pushToUndoStack(editorContent)
            isEditing = true
        }
    }
    
    func stopEditing() {
        isEditing = false
    }
    
    func updateContent(_ newContent: String) {
        if isEditing {
            let oldContent = editorContent
            editorContent = newContent
            hasUnsavedChanges = true
            
            if abs(oldContent.count - newContent.count) > 10 {
                pushToUndoStack(oldContent)
            }
            
            scheduleValidation()
        }
    }
    
    func saveChanges() {
        guard let configFile = configFile, hasUnsavedChanges else { 
            self.isEditing = false
            return
        }
        
        if case .invalid(_) = validationState {
            messageHandler.show("Config contains errors, cannot save", type: .error)
            return
        }
        
        Task {
            do {
                try editorContent.write(to: configFile.filePath, atomically: true, encoding: .utf8)
                
                let validationResult = await validateYamlContent(editorContent)
                
                switch validationResult {
                case .success:
                    var updatedFile = configFile
                    updatedFile.updateYamlContent(editorContent)
                    updatedFile.status = .valid
                    
                    await MainActor.run {
                        self.configFile = updatedFile
                        self.hasUnsavedChanges = false
                        self.clearRedoStack()
                        self.messageHandler.show("Config saved", type: .success)
                        self.isEditing = false
                    }
                    
                    if configFile.fileType == .active {
                        EventManager.shared.notifyActiveConfigChanged(editorContent)
                    }
                    
                case .failure(let error):
                    var updatedFile = configFile
                    updatedFile.updateYamlContent(editorContent)
                    updatedFile.markAsInvalid(error.localizedDescription)
                    
                    await MainActor.run {
                        self.configFile = updatedFile
                        self.messageHandler.show("Config saved, but validation failed: \(error.localizedDescription)", type: .error)
                        self.hasUnsavedChanges = false
                        self.isEditing = false
                    }
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "Failed to save config: \(error.localizedDescription)"
                    self.messageHandler.show("Failed to save config", type: .error)
                }
            }
        }
    }
    
    func discardChanges() {
        if let configFile = configFile {
            loadConfigFile(configFile)
        }
    }
    
    private func pushToUndoStack(_ content: String) {
        undoStack.append(content)
        if undoStack.count > maxUndoHistory {
            undoStack.removeFirst()
        }
    }

    func undo() {
        guard !undoStack.isEmpty && isEditing else { return }
        redoStack.append(editorContent)
        let previousContent = undoStack.removeLast()
        editorContent = previousContent
        hasUnsavedChanges = !undoStack.isEmpty
        validateContent()
    }
    
    func redo() {
        guard !redoStack.isEmpty && isEditing else { return }
        pushToUndoStack(editorContent)
        let nextContent = redoStack.removeLast()
        editorContent = nextContent
        hasUnsavedChanges = true
        validateContent()
    }
    
    private func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
    }
    
    private func clearRedoStack() {
        redoStack.removeAll()
    }
    
    enum ValidationState: Equatable {
        case notValidated
        case validating
        case valid
        case invalid(String)
    }
    
    private func scheduleValidation() {
        validationTimer?.invalidate()
        validationState = .validating
        validationTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.validateContent()
            }
        }
    }
    
    func validateContent() {
        guard !editorContent.isEmpty else {
            validationState = .invalid("Config cannot be empty")
            return
        }
        
        Task {
            let validationResult = await validateYamlContent(editorContent)
            
            await MainActor.run {
                switch validationResult {
                case .success:
                    self.validationState = .valid
                case .failure(let error):
                    let errorMessage = "Validation failed: \(error.localizedDescription)"
                    self.validationState = .invalid(errorMessage)
                }
            }
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
            return .failure(.validation("YAML parsing error: \(error.localizedDescription)"))
        }
    }
    
    var isConfigValid: Bool {
        switch validationState {
        case .valid:
            return true
        default:
            return false
        }
    }
    
    var editorTitle: String {
        configFile?.displayName ?? "No selected config"
    }
    
    var configStatus: KubeConfigFileStatus {
        configFile?.status ?? .unknown
    }
    
    var canUndo: Bool {
        isEditing && !undoStack.isEmpty
    }
    
    var canRedo: Bool {
        isEditing && !redoStack.isEmpty
    }
} 
