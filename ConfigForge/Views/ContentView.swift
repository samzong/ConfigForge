//
//  ContentView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI
import UniformTypeIdentifiers

// MARK: - Main Content View

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var isShowingRestoreFilePicker = false
    @State private var isShowingBackupFilePicker = false
    
    var body: some View {
        // Main layout using extracted components
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
            
            Rectangle().fill(Color.gray.opacity(0.2)).frame(width: 1) // Divider
            
            EditorAreaView(viewModel: viewModel)
        }
        // Apply original modifiers
        .frame(minWidth: 800, minHeight: 500)
        .background(Color(.windowBackgroundColor))
        .fileExporter(
            isPresented: $isShowingBackupFilePicker,
            document: ConfigDocument(content: formatCurrentConfigContent(viewModel: viewModel), 
                                     type: ConfigContentType.from(type: viewModel.selectedConfigurationType)),
            contentType: ConfigContentType.from(type: viewModel.selectedConfigurationType).utType,
            defaultFilename: defaultBackupFilename(for: viewModel.selectedConfigurationType)
        ) { [viewModel] result in
            switch result {
            case .success(let url):
                // Call the appropriate backup method based on selected type
                switch viewModel.selectedConfigurationType {
                case .ssh:
                    viewModel.backupSshConfig(to: url)
                case .kubernetes:
                    viewModel.backupKubeConfig(to: url)
                }
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: viewModel.getMessageHandler())
            }
        }
        .fileImporter(
            isPresented: $isShowingRestoreFilePicker,
            allowedContentTypes: ConfigDocument.readableContentTypes
        ) { result in
            handleFileImport(result: result)
        }
        .loadingOverlay(isLoading: viewModel.getAsyncUtility().isLoading)
        .messageOverlay(messageHandler: viewModel.getMessageHandler())
    }
    
    // MARK: - File Import Handling
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Cannot access security scoped resource for import.")
                viewModel.postMessage(L10n.Error.cannotAccessImportFile, type: .error)
                return
            }
            // Call the restore method (using explicit self) within a Task
            Task {
                self.viewModel.restoreCurrentConfig(from: url)
            }
            url.stopAccessingSecurityScopedResource()
        case .failure(let error):
            print("File import error: \(error.localizedDescription)")
            // Handle cancellation or other errors
             if error.localizedDescription != "The operation couldn't be completed. (SwiftUI.FileImporterPlatformSupport/EK_DEF_CANCEL error 1.)" {
                viewModel.postMessage(L10n.Error.fileImportFailed(error.localizedDescription), type: .error)
             }
        }
    }

    // MARK: - Helper Functions
    private func formatCurrentConfigContent(viewModel: MainViewModel) -> String {
        switch viewModel.selectedConfigurationType {
        case .ssh:
            let parser = SSHConfigParser() 
            return parser.formatConfig(entries: viewModel.sshEntries)
        case .kubernetes:
            if let kubeConfig = viewModel.kubeConfig {
                let parser = KubeConfigParser()
                let result = parser.encode(config: kubeConfig)
                switch result {
                case .success(let yamlString):
                    return yamlString
                case .failure(let error):
                    print("Error formatting Kubernetes config: \(error.localizedDescription)")
                    // Return a formatted error message as fallback
                    return "# Error formatting Kubernetes config: \(error.localizedDescription)\n# Data summary: \(viewModel.kubeContexts.count) contexts, \(viewModel.kubeClusters.count) clusters, \(viewModel.kubeUsers.count) users"
                }
            } else {
                return "# No Kubernetes config loaded"
            }
        }
    }
    
    private func defaultBackupFilename(for type: ConfigType) -> String {
        let timestamp = DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .short)
                           .replacingOccurrences(of: "/", with: "-")
                           .replacingOccurrences(of: ":", with: "-")
                           .replacingOccurrences(of: " ", with: "_")
        switch type {
        case .ssh:
            let baseName = SSHConfigConstants.defaultBackupFileName 
            return "\(baseName)_\(timestamp).txt" 
        case .kubernetes:
            let baseName = KubeConfigConstants.defaultKubeBackupFileName 
            return "\(baseName)_\(timestamp).yaml"
        }
    }
}
