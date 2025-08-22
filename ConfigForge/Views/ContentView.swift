
import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var isShowingRestoreFilePicker = false
    @State private var isShowingBackupFilePicker = false
    
    var body: some View {
        HStack(spacing: 0) {
            SidebarView(viewModel: viewModel)
            
            Rectangle().fill(Color.quaternary).frame(width: 1) 
            if viewModel.selectedConfigurationType == .kubernetes {
                ConfigEditorView()
                    .environmentObject(viewModel)
            } else {
                EditorAreaView(viewModel: viewModel)
            }
        }
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
    private func handleFileImport(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Cannot access security scoped resource for import.")
                viewModel.postMessage(L10n.Error.cannotAccessImportFile, type: .error)
                return
            }
            Task {
                viewModel.restoreCurrentConfig(from: url)
            }
            url.stopAccessingSecurityScopedResource()
        case .failure(let error):
            print("File import error: \(error.localizedDescription)")
            if error.localizedDescription != "The operation couldn't be completed. (SwiftUI.FileImporterPlatformSupport/EK_DEF_CANCEL error 1.)" {
                viewModel.postMessage(L10n.Error.fileImportFailed(error.localizedDescription), type: .error)
            }
        }
    }
    private func formatCurrentConfigContent(viewModel: MainViewModel) -> String {
        switch viewModel.selectedConfigurationType {
        case .ssh:
            let parser = SSHConfigParser() 
            return parser.formatConfig(entries: viewModel.sshEntries)
        case .kubernetes:
            if !viewModel.activeConfigContent.isEmpty {
                return viewModel.activeConfigContent
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
