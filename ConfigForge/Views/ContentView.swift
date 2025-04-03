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
    // 使用@StateObject直接初始化，不使用两段式初始化
    @StateObject private var viewModel = SSHConfigViewModel()
    @State private var isShowingRestoreFilePicker = false
    @State private var isShowingBackupFilePicker = false
    
    var body: some View {
        mainSplitView
            .navigationSplitViewStyle(.balanced) // 确保适当的尺寸比例
            .toolbar { toolbarContent }
            .fileExporter(
                isPresented: $isShowingBackupFilePicker,
                document: SSHConfigDocument(configContent: viewModel.parser.formatConfig(entries: viewModel.entries)),
                contentType: .text,
                defaultFilename: AppConstants.defaultBackupFileName
            ) { exportResult(result: $0) }
            .fileImporter(
                isPresented: $isShowingRestoreFilePicker,
                allowedContentTypes: [.text],
                allowsMultipleSelection: false
            ) { importResult(result: $0) }
            .overlay { messageOverlay }
            .alert(item: errorBinding) { errorAlert(error: $0) }
    }
    
    // 主分割视图
    private var mainSplitView: some View {
        NavigationSplitView {
            sidebarContent
        } detail: {
            detailContent
        }
    }
    
    // 侧边栏内容
    private var sidebarContent: some View {
        VStack(spacing: 0) {
            searchBar
            
            ZStack(alignment: .bottom) {
                hostList
                
                // 添加按钮 - 底部放置
                Button(action: {
                    // 添加新条目
                    let newEntry = SSHConfigEntry(host: "new-host", properties: [:])
                    viewModel.isEditing = true 
                    viewModel.selectedEntry = newEntry
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                        Text("添加主机")
                    }
                    .padding(8)
                    .background(Color.accentColor)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(8)
            }
        }
        .frame(minWidth: 220)
    }
    
    // 搜索栏
    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("搜索主机", text: $viewModel.searchText)
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
        .padding(.horizontal)
        .padding(.top, 12)
    }
    
    // 主机列表
    private var hostList: some View {
        List {
            ForEach(viewModel.filteredEntries) { entry in
                HostRowModern(entry: entry, isSelected: Binding(
                    get: { viewModel.selectedEntry?.id == entry.id },
                    set: { if $0 { viewModel.selectedEntry = entry } }
                ), viewModel: viewModel)
                .listRowBackground(viewModel.selectedEntry?.id == entry.id ? Color.accentColor.opacity(0.1) : Color.clear)
                .contextMenu {
                    hostContextMenu(for: entry)
                }
            }
        }
        .listStyle(SidebarListStyle())
    }
    
    // 主机上下文菜单
    private func hostContextMenu(for entry: SSHConfigEntry) -> some View {
        Group {
            // 移除分组子菜单
            
            Button("删除", role: .destructive) {
                viewModel.deleteEntry(id: entry.id)
            }
        }
    }
    
    // 详情内容
    private var detailContent: some View {
        Group {
            if let selectedEntry = viewModel.selectedEntry {
                ModernEntryEditorView(viewModel: viewModel, entry: selectedEntry)
                    .id(selectedEntry.id) // 确保在selectedEntry变化时重建视图
            } else {
                EmptyEditorViewModern()
            }
        }
    }
    
    // 工具栏内容
    private var toolbarContent: some ToolbarContent {
        Group {
            // 优化保存按钮样式
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.saveConfig()
                }) {
                    HStack {
                        Image(systemName: "square.and.arrow.down")
                        Text("保存")
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.large)
            }
        }
    }
    
    // 消息覆盖层
    private var messageOverlay: some View {
        Group {
            if let message = viewModel.appMessage {
                MessageBannerViewModern(message: message) {
                    viewModel.appMessage = nil
                }
                .onAppear {
                    // 成功消息自动消失
                    if message.type == .success {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            if viewModel.appMessage?.id == message.id {
                                viewModel.appMessage = nil
                            }
                        }
                    }
                }
                .transition(.move(edge: .top).combined(with: .opacity))
                .animation(.easeInOut, value: viewModel.appMessage != nil)
            }
        }
    }
    
    // 错误绑定
    private var errorBinding: Binding<ErrorMessage?> {
        Binding(
            get: { viewModel.errorMessage != nil ? ErrorMessage(message: viewModel.errorMessage!) : nil },
            set: { viewModel.errorMessage = $0?.message }
        )
    }
    
    // 错误警告
    private func errorAlert(error: ErrorMessage) -> Alert {
        Alert(
            title: Text("错误"), 
            message: Text(error.message), 
            dismissButton: .default(Text("确定"))
        )
    }
    
    // 处理导出结果
    private func exportResult(result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            viewModel.backupConfig(to: url)
        case .failure(let error):
            viewModel.setMessage("无法导出备份: \(error.localizedDescription)", type: .error)
        }
    }
    
    // 处理导入结果
    private func importResult(result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                viewModel.restoreConfig(from: url)
            }
        case .failure(let error):
            viewModel.setMessage("无法导入备份: \(error.localizedDescription)", type: .error)
        }
    }
}

// 更现代的消息横幅视图 - 顶部居中简洁样式
struct MessageBannerViewModern: View {
    let message: AppMessage
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            // 顶部居中的消息提示
            HStack(spacing: 10) {
                Image(systemName: iconName)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(message.message)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                
                // 只有非成功消息才显示关闭按钮
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
            .background(
                Capsule()
                    .fill(bannerColor)
                    .shadow(color: Color.black.opacity(0.15), radius: 3, x: 0, y: 2)
            )
            .padding(.top, 12)
            
            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .zIndex(100) // 确保显示在最上层
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

// 修改主机行视图，进一步降低行高
struct HostRowModern: View {
    let entry: SSHConfigEntry
    @Binding var isSelected: Bool
    @ObservedObject var viewModel: SSHConfigViewModel
    
    var body: some View {
        Button(action: {
            viewModel.selectedEntry = entry
        }) {
            HStack(spacing: 8) {
                // 移除主机图标
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.host)
                        .font(.system(size: 13, weight: .medium))
                    
                    if let hostname = entry.hostname, !hostname.isEmpty {
                        Text(hostname)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
            }
            .padding(.vertical, 3)
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// 现代化的空编辑器视图
struct EmptyEditorViewModern: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
            
            Text("选择或创建SSH配置")
                .font(.headline)
                .foregroundColor(.primary)
            
            Text("从左侧列表选择一个条目进行编辑，或点击\"添加\"创建新配置")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor).opacity(0.5))
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
        if entry.properties.isEmpty && entry.host == "new-host" {
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
                        label: "HostName",
                        systemImage: "network",
                        value: Binding(
                            get: { editedProperties["HostName"] ?? "" },
                            set: { editedProperties["HostName"] = $0 }
                        ),
                        placeholder: "例如: example.com"
                    )
                    
                    // 用户名配置项
                    configPropertyView(
                        label: "User",
                        systemImage: "person.fill",
                        value: Binding(
                            get: { editedProperties["User"] ?? "" },
                            set: { editedProperties["User"] = $0 }
                        ),
                        placeholder: "例如: admin"
                    )
                    
                    // 端口配置项
                    configPropertyView(
                        label: "Port",
                        systemImage: "link",
                        value: Binding(
                            get: { editedProperties["Port"] ?? "22" },
                            set: { editedProperties["Port"] = $0 }
                        ),
                        placeholder: "默认: 22"
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
            Label("IdentityFile", systemImage: "key.fill")
                .font(.headline)
                .foregroundColor(.primary)
            
            HStack {
                TextField("例如: ~/.ssh/id_rsa", text: Binding(
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
        HStack {
            // 移除主机图标
            
            VStack(alignment: .leading, spacing: 4) {
                if viewModel.isEditing {
                    // 让new-host输入框更加明显
                    TextField("请输入主机名", text: $editedHost)
                        .font(.title2.bold())
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .onChange(of: editedHost) { newValue in
                            // 验证主机名
                            let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.*?"))
                            hostValid = newValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil && !newValue.isEmpty
                        }
                        // 如果是new-host，添加视觉提示
                        .background(entry.host == "new-host" ? Color.accentColor.opacity(0.1) : Color.clear)
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(entry.host == "new-host" ? Color.accentColor : Color.clear, lineWidth: 1)
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
            
            // 编辑/保存按钮 - 移除prominence参数
            Button(viewModel.isEditing ? "保存" : "编辑") {
                if viewModel.isEditing {
                    if !hostValid || editedHost.isEmpty {
                        viewModel.setMessage("主机名无效，请修正后再保存", type: .error)
                        return
                    }
                    
                    // 保存编辑
                    if entry.id == UUID() || entry.host == "new-host" { // 新条目
                        viewModel.addEntry(host: editedHost, properties: editedProperties)
                    } else {
                        viewModel.updateEntry(id: entry.id, host: editedHost, properties: editedProperties)
                    }
                }
                viewModel.isEditing.toggle()
            }
            .keyboardShortcut(.return, modifiers: .command)
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .foregroundColor(viewModel.isEditing ? .white : .primary)
            .background(viewModel.isEditing ? Color.accentColor : Color.clear)
            .cornerRadius(4)
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
