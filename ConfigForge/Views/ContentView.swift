//
//  ContentView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI
import UniformTypeIdentifiers

// 添加一个可识别的错误消息结构体
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - Helper Structs for Refactoring

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedListIndex: Int?
    
    var body: some View {
        // Original Sidebar VStack content goes here
        VStack(spacing: 0) {
            // 添加Logo和应用名称以及顶部按钮
            HStack {
                Image("Logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                Text("ConfigForge")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
                
                // 保存按钮
                Button(action: {
                    viewModel.saveCurrentConfig()
                }) {
                    Text("app.save".cfLocalized)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.small)
                .keyboardShortcut("s", modifiers: .command)
                .help("app.save.help".cfLocalized)
            }
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 4)
            
            // ---- Top Navigation Picker (SSH / Kubernetes) ----
            Picker("", selection: $viewModel.selectedConfigurationType) {
                ForEach(ConfigType.allCases) { type in
                    Text(type.rawValue.cfLocalized).tag(type)
                }
            }
            .pickerStyle(.segmented) // Use segmented style for top level
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            // ---- End Top Navigation Picker ----
            
            // 搜索区域
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("sidebar.search".cfLocalized, text: $viewModel.searchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.searchText.isEmpty {
                    Button(action: {
                        viewModel.searchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding([.horizontal, .top], 8)
            
            // ---- Secondary Kubernetes Picker (Contexts/Clusters/Users) ----
            if viewModel.selectedConfigurationType == .kubernetes {
                Picker("", selection: $viewModel.selectedKubernetesObjectType) {
                    ForEach(KubeObjectType.allCases) { type in
                        Text(type.rawValue.cfLocalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 12)
                .padding(.top, 4) // Add some space below search bar
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .scale(scale: 0.9, anchor: .top))) // Optional animation
            }
            // ---- End Secondary Kubernetes Picker ----
            
            // 主机列表区域
            List(viewModel.displayedEntries.indices, id: \.self, selection: $selectedListIndex) { index in
                 // Get entry using index with safety check
                 if index < viewModel.displayedEntries.count {
                     let entry = viewModel.displayedEntries[index]
                     
                     // Determine which row view to display
                     if let sshEntry = entry as? SSHConfigEntry {
                         HostRowView(entry: sshEntry)
                             .tag(sshEntry.id as AnyHashable)
                             .contextMenu {
                                 Button(role: .destructive) {
                                     viewModel.deleteSshEntry(id: sshEntry.id) // Use specific delete method
                                 } label: {
                                     Label("app.delete".cfLocalized, systemImage: "trash")
                                 }
                             }
                     } else if let kubeContext = entry as? KubeContext {
                         KubeContextRowView(context: kubeContext, isCurrent: viewModel.currentKubeContextName == kubeContext.name)
                             .tag(kubeContext.id as AnyHashable)
                             .contextMenu {
                                 // Connect action to ViewModel method
                                 Button { viewModel.setCurrentKubeContext(name: kubeContext.name) } label: {
                                     Label("Set as Current Context", systemImage: "star.circle.fill")
                                 }
                                  // Disable if already current? Optional UX improvement
                                 .disabled(viewModel.currentKubeContextName == kubeContext.name) 
                                 Divider()
                                 Button(role: .destructive) {
                                     viewModel.deleteKubeContext(id: kubeContext.id)
                                 } label: {
                                     Label("app.delete".cfLocalized, systemImage: "trash")
                                 }
                             }
                             .onTapGesture {
                                 // 强制刷新选择，即使是点击当前已选中的项目
                                 let currentlySelectedId = viewModel.selectedEntry?.id as? String
                                 if currentlySelectedId == kubeContext.id {
                                     // 如果点击当前选中项，先取消选择再重新选择，强制刷新
                                     viewModel.safelySelectEntry(nil)
                                     DispatchQueue.main.async {
                                         viewModel.safelySelectEntry(kubeContext)
                                     }
                                 } else {
                                     viewModel.safelySelectEntry(kubeContext)
                                 }
                             }
                     } else if let kubeCluster = entry as? KubeCluster {
                         // 使用简单的行视图显示，而不是在边栏嵌入编辑器
                         KubeClusterRowView(cluster: kubeCluster)
                             .tag(kubeCluster.id as AnyHashable)
                             .contextMenu {
                                 Button(role: .destructive) {
                                     viewModel.deleteKubeCluster(id: kubeCluster.id)
                                 } label: {
                                     Label("app.delete".cfLocalized, systemImage: "trash")
                                 }
                             }
                             .onTapGesture {
                                 // 强制刷新选择，即使是点击当前已选中的项目
                                 let currentlySelectedId = viewModel.selectedEntry?.id as? String
                                 if currentlySelectedId == kubeCluster.id {
                                     // 如果点击当前选中项，先取消选择再重新选择，强制刷新
                                     viewModel.safelySelectEntry(nil)
                                     DispatchQueue.main.async {
                                         viewModel.safelySelectEntry(kubeCluster)
                                     }
                                 } else {
                                     viewModel.safelySelectEntry(kubeCluster)
                                 }
                             }
                     } else if let kubeUser = entry as? KubeUser {
                         KubeUserRowView(user: kubeUser) // Use existing Row View
                             .tag(kubeUser.id as AnyHashable)
                             .contextMenu {
                                  Button(role: .destructive) {
                                     viewModel.deleteKubeUser(id: kubeUser.id)
                                 } label: {
                                     Label("app.delete".cfLocalized, systemImage: "trash")
                                 }
                             }
                             .onTapGesture {
                                 // 强制刷新选择，即使是点击当前已选中的项目
                                 let currentlySelectedId = viewModel.selectedEntry?.id as? String
                                 if currentlySelectedId == kubeUser.id {
                                     // 如果点击当前选中项，先取消选择再重新选择，强制刷新
                                     viewModel.safelySelectEntry(nil)
                                     DispatchQueue.main.async {
                                         viewModel.safelySelectEntry(kubeUser)
                                     }
                                 } else {
                                     viewModel.safelySelectEntry(kubeUser)
                                 }
                             }
                     } else {
                         Text("Unknown entry type") 
                     }
                 } else {
                     Text("Loading...") // Placeholder for out-of-bounds index
                 }
            }
            .listStyle(.sidebar)
            .onChange(of: selectedListIndex) { newIndex in
                // Sync list index selection TO ViewModel selection
                let currentlySelectedVMEntryId = viewModel.selectedEntry?.id as? AnyHashable
                var newEntryToSelect: (any Identifiable)? = nil
                if let index = newIndex, index >= 0 && index < viewModel.displayedEntries.count {
                    newEntryToSelect = viewModel.displayedEntries[index]
                }
                if currentlySelectedVMEntryId != newEntryToSelect?.id as? AnyHashable {
                    viewModel.safelySelectEntry(newEntryToSelect)
                }
            }
            // Ensure this observes ID as AnyHashable and uses hashable comparison
            .onChange(of: viewModel.selectedEntry?.id as? AnyHashable) { selectedIdHashable in 
                // Sync ViewModel selection TO list index selection
                let currentlySelectedListIndexEntryId = (selectedListIndex != nil && selectedListIndex! >= 0 && selectedListIndex! < viewModel.displayedEntries.count) ? viewModel.displayedEntries[selectedListIndex!].id as? AnyHashable : nil
                
                // Only update List index if the selection ID actually changes
                if selectedIdHashable != currentlySelectedListIndexEntryId { // Compare hashables
                    if let idToSelect = selectedIdHashable, // idToSelect is AnyHashable?
                       let newIndex = viewModel.displayedEntries.firstIndex(where: { ($0.id as? AnyHashable) == idToSelect }) { // Compare hashables in find
                        selectedListIndex = newIndex
                    } else {
                        selectedListIndex = nil // Deselect if ViewModel selection is nil or not found
                    }
                }
            }
            
            Divider()
            
            // 底部添加按钮
            Button(action: {
                switch viewModel.selectedConfigurationType {
                case .ssh:
                    // Existing SSH add logic
                    let newHostString = "host.new".cfLocalized
                    let newEntry = SSHConfigEntry(host: newHostString, properties: [:])
                    viewModel.sshEntries.append(newEntry) // Add to sshEntries
                    viewModel.safelySelectEntry(newEntry)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isEditing = true
                        }
                    }

                case .kubernetes:
                    switch viewModel.selectedKubernetesObjectType {
                    case .contexts:
                        viewModel.addKubeContext() 
                    case .clusters:
                        viewModel.addKubeCluster() 
                    case .users:
                        viewModel.addKubeUser()    
                    }
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(addButtoText()) 
                }
                .frame(maxWidth: .infinity)
                .padding(8)
                .background(Color.accentColor)
                .foregroundColor(.white)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .padding(8)
        }
        .frame(width: 250)
    }
    
    // Helper function for dynamic Add button text (Copied from ContentView)
    private func addButtoText() -> String {
        switch viewModel.selectedConfigurationType {
        case .ssh:
            return "sidebar.add.host".cfLocalized
        case .kubernetes:
            switch viewModel.selectedKubernetesObjectType {
            case .contexts: return "sidebar.add.context".cfLocalized
            case .clusters: return "sidebar.add.cluster".cfLocalized
            case .users: return "sidebar.add.user".cfLocalized
            }
        }
    }
}

struct EditorAreaView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        // Original ZStack content for editor area goes here
        ZStack {
            if let selectedEntry = viewModel.selectedEntry {
                // --- Dynamically display the correct editor based on type --- 
                if let sshEntry = selectedEntry as? SSHConfigEntry {
                    ModernEntryEditorView(viewModel: viewModel, entry: sshEntry)
                        .id(sshEntry.id) 
                } else if let kubeContext = selectedEntry as? KubeContext {
                     // 实现KubeContextEditorView
                     if let contextIndex = viewModel.kubeContexts.firstIndex(where: { $0.id == kubeContext.id }) {
                         KubeContextEditorView(viewModel: viewModel, context: $viewModel.kubeContexts[contextIndex])
                             .id(kubeContext.id)
                     } else {
                         Text("error.binding.context".cfLocalized).foregroundColor(.red)
                     }
                } else if let kubeCluster = selectedEntry as? KubeCluster {
                     // 将KubeClusterEditorView移到主区域显示
                     if let clusterIndex = viewModel.kubeClusters.firstIndex(where: { $0.id == kubeCluster.id }) {
                         KubeClusterEditorView(viewModel: viewModel, cluster: $viewModel.kubeClusters[clusterIndex])
                            .id(kubeCluster.id)
                     } else {
                         Text("error.binding.cluster".cfLocalized).foregroundColor(.red)
                     }
                } else if let kubeUser = selectedEntry as? KubeUser {
                    // 实现KubeUserEditorView
                    if let userIndex = viewModel.kubeUsers.firstIndex(where: { $0.id == kubeUser.id }) {
                        KubeUserEditorView(viewModel: viewModel, user: $viewModel.kubeUsers[userIndex])
                            .id(kubeUser.id)
                    } else {
                        Text("error.binding.user".cfLocalized).foregroundColor(.red)
                    }
                } else {
                    Text("error.editor.unknown".cfLocalized)
                        .foregroundColor(.secondary)
                }
            } else {
                EmptyEditorViewModern()
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Main Content View (Refactored)

struct ContentView: View {
    @StateObject private var viewModel = MainViewModel()
    @State private var isShowingRestoreFilePicker = false
    @State private var isShowingBackupFilePicker = false
    
    var body: some View {
        // Refactored body using SidebarView and EditorAreaView
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
            allowedContentTypes: ConfigDocument.readableContentTypes // Use types from ConfigDocument
        ) { result in
            // Call the new handler method
            handleFileImport(result: result)
        }
        .loadingOverlay(isLoading: viewModel.getAsyncUtility().isLoading)
        .messageOverlay(messageHandler: viewModel.getMessageHandler())
    }
    
    // MARK: - File Import Handling (NEW METHOD)
    private func handleFileImport(result: Result<URL, Error>) {
        // Access viewModel directly as it's a @StateObject in ContentView
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                print("Error: Cannot access security scoped resource for import.")
                viewModel.postMessage("error.cannotAccessImportFile".cfLocalized, type: .error)
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
                viewModel.postMessage("error.fileImportFailed".cfLocalized(with: error.localizedDescription), type: .error)
             }
        }
    }
    
    // Keep helper functions formatCurrentConfigContent and defaultBackupFilename in ContentView
    // as they relate to the fileExporter which is still attached here.
    // Remove addButtoText as it was moved to SidebarView.

    // MARK: - Helper Functions (Kept)

    private func formatCurrentConfigContent(viewModel: MainViewModel) -> String {
        switch viewModel.selectedConfigurationType {
        case .ssh:
            let parser = SSHConfigParser() 
            return parser.formatConfig(entries: viewModel.sshEntries)
        case .kubernetes:
            print("Warning: Kubernetes config formatting not implemented, returning placeholder.")
            // Use ViewModel's direct properties for counts as KubeConfig structure isn't fully known
            // and these properties are managed directly by the ViewModel.
            if viewModel.kubeConfig != nil { // Check if config is loaded
                 // Attempt basic dump (requires a YAML library or manual formatting)
                 // return KubeConfigFormatter.format(config) // Ideal
                 return "# Kubernetes config placeholder\napiVersion: v1\nkind: Config\n# Data: \(viewModel.kubeContexts.count) contexts, \(viewModel.kubeClusters.count) clusters, \(viewModel.kubeUsers.count) users" // USE VIEWMODEL PROPERTIES
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
            let baseName = ConfigForgeConstants.defaultBackupFileName 
            return "\(baseName)_\(timestamp).txt" 
        case .kubernetes:
            let baseName = ConfigForgeConstants.defaultKubeBackupFileName 
            return "\(baseName)_\(timestamp).yaml"
        }
    }
}

// Keep HostRowView, MessageBanner, SSHConfigDocument, etc. below ContentView
// Ensure Kube related RowViews and EditorViews are defined somewhere accessible

// ... (rest of the file: HostRowView, MessageBanner, SSHConfigDocument, EmptyEditorViewModern, ModernEntryEditorView, KubeContextRowView, KubeClusterRowView, KubeUserRowView) ...

// 主机行视图
struct HostRowView: View {
    let entry: SSHConfigEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.host)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            if !entry.hostname.isEmpty {
                Text(entry.hostname)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

// 消息横幅
struct MessageBanner: View {
    let message: AppMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: iconName)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            
            Text(message.message)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.white)
            
            if message.type != .success {
                Button(action: {
                    // 直接调用 dismiss 操作
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Capsule().fill(bannerColor))
        .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
        .padding(.top, 12)
    }
    
    private var iconName: String {
        switch message.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var bannerColor: Color {
        switch message.type {
        case .success: return Color.green.opacity(0.9)
        case .error: return Color.red.opacity(0.9)
        case .info: return Color.blue.opacity(0.9)
        }
    }
}

// 为文件导出器创建一个文档类型
struct SSHConfigDocument: FileDocument, Sendable {
    static let readableContentTypes: [UTType] = [.text]
    
    var configContent: String
    
    init(configContent: String) {
        self.configContent = configContent
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let content = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        configContent = content
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = configContent.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
}

// 现代化的空编辑器视图
struct EmptyEditorViewModern: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 10)
            
            LocalizedText("editor.empty.title")
                .font(.title3)
                .foregroundColor(.primary)
            
            LocalizedText("editor.empty.description")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

// 修改条目编辑器视图，统一编辑和非编辑状态下的界面样式
struct ModernEntryEditorView: View {
    @ObservedObject var viewModel: MainViewModel
    var entry: SSHConfigEntry
    @State private var editedHost: String
    @State private var editedProperties: [String: String]
    @State private var hostValid: Bool = true
    @State private var isShowingFilePicker = false
    @State private var currentEditingKey = ""
    
    init(viewModel: MainViewModel, entry: SSHConfigEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedHost = State(initialValue: entry.host)
        
        // 为新条目添加默认属性
        let newHostString = "host.new".cfLocalized
        if entry.properties.isEmpty && entry.host == newHostString {
            let defaultProperties: [String: String] = [
                "HostName": "",
                "User": "",
                "Port": "22"
            ]
            _editedProperties = State(initialValue: defaultProperties)
        } else {
            // 确保包含HostName属性
            var updatedProperties = entry.properties
            if !updatedProperties.keys.contains("HostName") {
                updatedProperties["HostName"] = ""
            }
            _editedProperties = State(initialValue: updatedProperties)
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // 主机名配置项
                    configPropertyView(
                        label: "property.hostname".cfLocalized,
                        systemImage: "network",
                        value: Binding(
                            get: { editedProperties["HostName"] ?? "" },
                            set: { editedProperties["HostName"] = $0 }
                        ),
                        placeholder: "property.hostname.placeholder".cfLocalized
                    )
                    
                    // 用户名配置项
                    configPropertyView(
                        label: "property.user".cfLocalized,
                        systemImage: "person.fill",
                        value: Binding(
                            get: { editedProperties["User"] ?? "" },
                            set: { editedProperties["User"] = $0 }
                        ),
                        placeholder: "property.user.placeholder".cfLocalized
                    )
                    
                    // 端口配置项
                    configPropertyView(
                        label: "property.port".cfLocalized,
                        systemImage: "number.circle",
                        value: Binding(
                            get: { editedProperties["Port"] ?? "22" },
                            set: { editedProperties["Port"] = $0 }
                        ),
                        placeholder: "property.port.placeholder".localized
                    )
                    
                    // 身份文件配置项 - 包含文件选择器
                    identityFileView
                    
                    // 其他配置项 - 展示所有其他属性
                    ForEach(otherPropertyKeys, id: \.self) { key in
                        configPropertyView(
                            label: key,
                            systemImage: "doc.text",
                            value: Binding(
                                get: { editedProperties[key] ?? "" },
                                set: { editedProperties[key] = $0 }
                            )
                        )
                    }
                    
                    // 移除"添加其他属性"按钮
                }
                .padding()
                .animation(.easeInOut(duration: 0.2), value: viewModel.isEditing)
            }
        }
        .background(Color(.windowBackgroundColor))
        .id(entry.id)
    }
    
    // 统一编辑和非编辑状态下的UI样式
    private func configPropertyView(label: String, systemImage: String, value: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: systemImage)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 统一 UI 样式：使用ZStack叠加TextField和Text，根据状态显示不同视图
            ZStack(alignment: .leading) {
                // 两种状态下都使用相同的底层样式，保持视觉一致性
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color(NSColor.textBackgroundColor))
                    .frame(height: 30)
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                
                // 编辑状态时显示可编辑的TextField
                if viewModel.isEditing {
                    TextField(placeholder, text: value)
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                } else {
                    // 非编辑状态时显示只读的Text
                    Text(value.wrappedValue.isEmpty ? placeholder : value.wrappedValue)
                        .foregroundColor(value.wrappedValue.isEmpty ? .gray.opacity(0.5) : .primary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                }
            }
            .frame(height: 30)
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // 身份文件视图 - 带文件选择器，同样统一UI样式
    private var identityFileView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("property.identityfile".localized, systemImage: "key.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                // 使用与其他输入字段相同的ZStack结构
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 5)
                        .fill(Color(NSColor.textBackgroundColor))
                        .frame(height: 30)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                    
                    // 编辑状态下的TextField
                    if viewModel.isEditing {
                        TextField("property.identityfile.placeholder".localized, text: Binding(
                            get: { editedProperties["IdentityFile"] ?? "" },
                            set: { editedProperties["IdentityFile"] = $0 }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    } else {
                        // 非编辑状态下的Text
                        let value = editedProperties["IdentityFile"] ?? ""
                        Text(value.isEmpty ? "property.identityfile.placeholder".localized : value)
                            .foregroundColor(value.isEmpty ? .gray.opacity(0.5) : .primary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 4)
                    }
                }
                .frame(height: 30)
                
                // 文件选择器按钮保持在同样位置但根据状态更改透明度
                Button(action: {
                    if viewModel.isEditing {
                        selectIdentityFile()
                    }
                }) {
                    Image(systemName: "folder")
                        .foregroundColor(.blue)
                }
                .buttonStyle(BorderedButtonStyle())
                .disabled(!viewModel.isEditing)
                .opacity(viewModel.isEditing ? 1.0 : 0.5)
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // 使用NSOpenPanel选择文件
    private func selectIdentityFile() {
        let openPanel = NSOpenPanel()
        openPanel.title = "选择SSH密钥文件"
        openPanel.showsResizeIndicator = true
        openPanel.showsHiddenFiles = true  // 显示隐藏文件，因为.ssh目录通常是隐藏的
        openPanel.canChooseDirectories = false
        openPanel.canCreateDirectories = false
        openPanel.allowsMultipleSelection = false
        openPanel.allowedContentTypes = [.text, .data]  // 允许文本和数据文件
        
        openPanel.begin { (result) in
            if result == .OK, let url = openPanel.url {
                DispatchQueue.main.async {
                    self.editedProperties["IdentityFile"] = url.path
                    print("已选择文件路径: \(url.path)")
                }
            }
        }
    }
    
    // 顶部信息栏，优化布局稳定性
    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                // 使用ZStack保持一致的高度和位置，避免布局跳动
                ZStack {
                    // 获取本地化的新主机标识
                    let newHostString = "host.new".localized
                    
                    // 编辑状态时显示TextField
                    if viewModel.isEditing {
                        TextField("host.enter.name".localized, text: $editedHost)
                            .font(.title2.bold())
                            .textFieldStyle(PlainTextFieldStyle())
                            .frame(maxWidth: 300, minHeight: 40)
                            .padding(4)
                            .background(
                                RoundedRectangle(cornerRadius: 5)
                                    .fill(entry.host == newHostString ? Color.accentColor.opacity(0.1) : Color.clear)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 5)
                                            .stroke(entry.host == newHostString ? Color.accentColor : Color.clear, lineWidth: 1)
                                    )
                            )
                            .onChange(of: editedHost) { newValue in
                                // 验证主机名，使用Task.detached避免视图更新过程中直接修改状态
                                Task {
                                    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.*?"))
                                    let isValid = newValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil && !newValue.isEmpty
                                    
                                    await MainActor.run {
                                        hostValid = isValid
                                    }
                                }
                            }
                    } else {
                        // 非编辑状态时显示Text
                        Text(entry.host)
                            .font(.title2.bold())
                            .frame(maxWidth: 300, minHeight: 40, alignment: .leading)
                            .padding(4)
                    }
                }
                .frame(height: 40)
                
                HStack {
                    if !entry.hostname.isEmpty {
                        Text(entry.hostname)
                            .foregroundColor(.secondary)
                    }
                    
                    if !entry.user.isEmpty {
                        Text("@\(entry.user)")
                            .foregroundColor(.secondary)
                    }
                }
                .font(.subheadline)
            }
            
            Spacer()
            
            // 编辑/保存按钮
            Button(action: {
                if viewModel.isEditing {
                    if !hostValid || editedHost.isEmpty {
                        viewModel.getMessageHandler().show(AppConstants.ErrorMessages.emptyHostError, type: .error)
                        return
                    }
                    
                    // 获取本地化的新主机标识
                    let newHostString = "host.new".localized
                    
                    // 保存编辑
                    if entry.host == newHostString { // 新条目
                        // 移除临时添加的条目 (MODIFIED)
                        if let sshEntry = entry as? SSHConfigEntry, 
                           let index = viewModel.sshEntries.firstIndex(where: { $0.id == sshEntry.id }) {
                            viewModel.sshEntries.remove(at: index) // Use sshEntries
                        }
                        // 使用正式的添加方法 (Assume viewModel.addEntry handles SSH entries)
                        // Ensure addEntry exists and correctly handles the data
                        // If addEntry is specifically for SSH, maybe rename for clarity (e.g., addSshEntry)
                        // We'll assume addEntry is correct for now based on context.
                         viewModel.addSshEntry(host: editedHost, properties: editedProperties) // Use specific SSH add method
                    } else {
                        // Assume updateEntry handles SSH entries
                        // If updateEntry is specific, rename (e.g., updateSshEntry)
                        viewModel.updateSshEntry(id: entry.id, host: editedHost, properties: editedProperties) // Use specific SSH update method
                    }
                    
                    // 使用延迟调用避免在视图更新周期中切换状态
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isEditing.toggle()
                    }
                } else {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        viewModel.isEditing.toggle()
                    }
                }
            }) {
                Text(viewModel.isEditing ? "app.save".localized : "app.edit".localized)
                    .frame(minWidth: 80)
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .disabled(viewModel.isEditing && (!hostValid || editedHost.isEmpty))
        }
        .padding()
        .background(Color(NSColor.textBackgroundColor))
        .animation(.easeInOut(duration: 0.2), value: viewModel.isEditing)
    }
    
    // 获取除基本属性外的其他属性键
    private var otherPropertyKeys: [String] {
        let basicKeys = ["HostName", "User", "Port", "IdentityFile", "PreferredAuthentications"]
        return editedProperties.keys
            .filter { !basicKeys.contains($0) }
            .sorted()
    }
}

// MARK: - Placeholder Row Views for Kube Objects (NEW)

struct KubeContextRowView: View {
    let context: KubeContext
    let isCurrent: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(context.name)
                .font(.headline)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundColor(isCurrent ? .accentColor : .primary)
            
            Text("kubernetes.context.cluster.user.format".localized(context.context.cluster, context.context.user))
                .font(.caption)
                .foregroundColor(.secondary)
            if let namespace = context.context.namespace {
                Text("kubernetes.context.namespace.format".localized(namespace))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 2)
    }
}

struct KubeClusterRowView: View {
    let cluster: KubeCluster
    var body: some View {
        VStack(alignment: .leading) {
            Text(cluster.name).font(.headline)
            Text(cluster.cluster.server).font(.caption).foregroundColor(.secondary)
        }
         .padding(.vertical, 2)
    }
}

struct KubeUserRowView: View {
    let user: KubeUser
    var body: some View {
        VStack(alignment: .leading) {
             Text(user.name).font(.headline)
             // Display some indication of auth method if possible
             if user.user.token != nil {
                 Text("kubernetes.user.auth.token".localized).font(.caption).foregroundColor(.secondary)
             } else if user.user.clientCertificateData != nil {
                 Text("kubernetes.user.auth.cert".localized).font(.caption).foregroundColor(.secondary)
             } else {
                 Text("kubernetes.user.auth.other".localized).font(.caption).foregroundColor(.secondary)
             }
        }
         .padding(.vertical, 2)
    }
}
