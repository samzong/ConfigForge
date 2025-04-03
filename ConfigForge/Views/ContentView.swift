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

struct ContentView: View {
    @StateObject private var viewModel = SSHConfigViewModel()
    @State private var isShowingRestoreFilePicker = false
    @State private var isShowingBackupFilePicker = false
    
    var body: some View {
        HStack(spacing: 0) {
            // 左侧侧边栏
            VStack(spacing: 0) {
                // 搜索区域
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("sidebar.search".localized, text: $viewModel.searchText)
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
                
                // 主机列表区域
                List(selection: $viewModel.selectedEntry) {
                    ForEach(viewModel.filteredEntries) { entry in
                        HostRowView(entry: entry)
                            .tag(entry)
                            .contextMenu {
                                Button(role: .destructive) {
                                    viewModel.deleteEntry(id: entry.id)
                                } label: {
                                    Label("app.delete".localized, systemImage: "trash")
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
                
                Divider()
                
                // 底部添加按钮
                Button(action: {
                    let newHostString = "host.new".localized
                    let newEntry = SSHConfigEntry(host: newHostString, properties: [:])
                    viewModel.isEditing = true 
                    viewModel.selectedEntry = newEntry
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        LocalizedText("sidebar.add.host")
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
            
            // 分隔线
            Rectangle()
                .fill(Color.gray.opacity(0.2))
                .frame(width: 1)
            
            // 右侧详情区域
            ZStack {
                if let selectedEntry = viewModel.selectedEntry {
                    ModernEntryEditorView(viewModel: viewModel, entry: selectedEntry)
                        .id(selectedEntry.id)
                } else {
                    EmptyEditorViewModern()
                }
            }
            .frame(maxWidth: .infinity)
            .toolbar {
                ToolbarItem(placement: .automatic) {
                    Button(action: {
                        viewModel.saveConfig()
                    }) {
                        Label("app.save".localized, systemImage: "square.and.arrow.down")
                    }
                    .keyboardShortcut("s", modifiers: .command)
                    .help("app.save.help".localized)
                }
            }
        }
        .frame(minWidth: 800, minHeight: 500)
        .background(Color(.windowBackgroundColor))
        .fileExporter(
            isPresented: $isShowingBackupFilePicker,
            document: SSHConfigDocument(configContent: viewModel.parser.formatConfig(entries: viewModel.entries)),
            contentType: .text,
            defaultFilename: AppConstants.defaultBackupFileName
        ) { result in
            switch result {
            case .success(let url):
                viewModel.backupConfig(to: url)
            case .failure(let error):
                viewModel.setMessage("message.error.export.failed".localized(error.localizedDescription), type: .error)
            }
        }
        .fileImporter(
            isPresented: $isShowingRestoreFilePicker,
            allowedContentTypes: [.text],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    viewModel.restoreConfig(from: url)
                }
            case .failure(let error):
                viewModel.setMessage("message.error.import.failed".localized(error.localizedDescription), type: .error)
            }
        }
        .overlay {
            // 消息提示
            if let message = viewModel.appMessage {
                VStack {
                    MessageBanner(message: message) {
                        viewModel.appMessage = nil
                    }
                    Spacer()
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.appMessage != nil)
            }
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage != nil ? ErrorMessage(message: viewModel.errorMessage!) : nil },
            set: { viewModel.errorMessage = $0?.message }
        )) { error in
            Alert(
                title: Text("app.error".localized), 
                message: Text(error.message), 
                dismissButton: .default(Text("app.confirm".localized))
            )
        }
    }
}

// 主机行视图
struct HostRowView: View {
    let entry: SSHConfigEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.host)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            if let hostname = entry.hostname, !hostname.isEmpty {
                Text(hostname)
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
                Button(action: onDismiss) {
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
struct SSHConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.text] }
    
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
    @ObservedObject var viewModel: SSHConfigViewModel
    var entry: SSHConfigEntry
    @State private var editedHost: String
    @State private var editedProperties: [String: String]
    @State private var hostValid: Bool = true
    @State private var isShowingFilePicker = false
    @State private var currentEditingKey = ""
    
    init(viewModel: SSHConfigViewModel, entry: SSHConfigEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedHost = State(initialValue: entry.host)
        
        // 为新条目添加默认属性
        let newHostString = "host.new".localized
        if entry.properties.isEmpty && entry.host == newHostString {
            let defaultProperties: [String: String] = [
                "HostName": "",
                "User": "",
                "Port": "22",
                "IdentityFile": "",
                "PreferredAuthentications": "publickey"
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
                        label: "property.hostname".localized,
                        systemImage: "network",
                        value: Binding(
                            get: { editedProperties["HostName"] ?? "" },
                            set: { editedProperties["HostName"] = $0 }
                        ),
                        placeholder: "property.hostname.placeholder".localized
                    )
                    
                    // 用户名配置项
                    configPropertyView(
                        label: "property.user".localized,
                        systemImage: "person.fill",
                        value: Binding(
                            get: { editedProperties["User"] ?? "" },
                            set: { editedProperties["User"] = $0 }
                        ),
                        placeholder: "property.user.placeholder".localized
                    )
                    
                    // 端口配置项
                    configPropertyView(
                        label: "property.port".localized,
                        systemImage: "link",
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
            }
        }
        .background(Color(.windowBackgroundColor))
        .id(entry.id)
        .fileImporter(
            isPresented: $isShowingFilePicker,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                if let url = urls.first {
                    // 使用文件路径
                    editedProperties[currentEditingKey] = url.path
                }
            case .failure:
                // 处理错误情况
                break
            }
        }
    }
    
    // 统一编辑和非编辑状态下的UI样式
    private func configPropertyView(label: String, systemImage: String, value: Binding<String>, placeholder: String = "") -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(label, systemImage: systemImage)
                .font(.headline)
                .foregroundColor(.primary)
            
            // 统一 UI 样式：无论是否编辑，都显示TextField，只是根据状态控制是否可编辑
            TextField(placeholder, text: value)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(!viewModel.isEditing)
                .opacity(viewModel.isEditing ? 1.0 : 0.8)
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
                TextField("property.identityfile.placeholder".localized, text: Binding(
                    get: { editedProperties["IdentityFile"] ?? "" },
                    set: { editedProperties["IdentityFile"] = $0 }
                ))
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .disabled(!viewModel.isEditing)
                .opacity(viewModel.isEditing ? 1.0 : 0.8)
                
                // 文件选择器按钮只在编辑模式下显示
                if viewModel.isEditing {
                    Button(action: {
                        currentEditingKey = "IdentityFile"
                        isShowingFilePicker = true
                    }) {
                        Image(systemName: "folder")
                            .foregroundColor(.blue)
                    }
                    .buttonStyle(BorderedButtonStyle())
                }
            }
        }
        .padding()
        .background(Color.secondary.opacity(0.05))
        .cornerRadius(8)
    }
    
    // 顶部信息栏，优化new-host输入框显示
    private var headerView: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.isEditing {
                    // 获取本地化的新主机标识
                    let newHostString = "host.new".localized
                    
                    // 让new-host输入框更加明显
                    TextField("host.enter.name".localized, text: $editedHost)
                        .font(.title2.bold())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(maxWidth: 300)
                        .onChange(of: editedHost) { newValue in
                            // 验证主机名
                            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.*?"))
                            hostValid = newValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil && !newValue.isEmpty
                        }
                        // 如果是new-host，添加视觉提示
                        .background(entry.host == newHostString ? Color.accentColor.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(entry.host == newHostString ? Color.accentColor : Color.clear, lineWidth: 1)
                        )
                } else {
                    Text(entry.host)
                        .font(.title2.bold())
                }
                
                HStack {
                    if let hostname = entry.hostname, !hostname.isEmpty {
                        Text(hostname)
                            .foregroundColor(.secondary)
                    }
                    
                    if let user = entry.user, !user.isEmpty {
                        Text("@\(user)")
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
                        viewModel.setMessage("host.invalid".localized, type: .error)
                        return
                    }
                    
                    // 获取本地化的新主机标识
                    let newHostString = "host.new".localized
                    
                    // 保存编辑
                    if entry.id == UUID() || entry.host == newHostString { // 新条目
                        viewModel.addEntry(host: editedHost, properties: editedProperties)
                    } else {
                        viewModel.updateEntry(id: entry.id, host: editedHost, properties: editedProperties)
                    }
                }
                viewModel.isEditing.toggle()
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
    }
    
    // 获取除基本属性外的其他属性键
    private var otherPropertyKeys: [String] {
        let basicKeys = ["HostName", "User", "Port", "IdentityFile", "PreferredAuthentications"]
        return editedProperties.keys
            .filter { !basicKeys.contains($0) }
            .sorted()
    }
}
