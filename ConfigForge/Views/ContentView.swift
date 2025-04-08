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
                        viewModel.saveConfig()
                    }) {
                        Text("app.save".localized)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
                    .keyboardShortcut("s", modifiers: .command)
                    .help("app.save.help".localized)
                }
                .padding([.horizontal, .top], 12)
                .padding(.bottom, 4)
                
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
                List(viewModel.filteredEntries, selection: Binding(
                    get: { viewModel.selectedEntry },
                    set: { newValue in
                        viewModel.safelySelectEntry(newValue)
                    }
                )) { entry in
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
                .listStyle(.sidebar)
                
                Divider()
                
                // 底部添加按钮
                Button(action: {
                    let newHostString = "host.new".localized
                    let newEntry = SSHConfigEntry(host: newHostString, properties: [:])
                    viewModel.entries.append(newEntry)
                    viewModel.selectedEntry = newEntry
                    
                    // 立即进入编辑模式
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isEditing = true
                        }
                    }
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
        }
        .frame(minWidth: 800, minHeight: 500)
        .background(Color(.windowBackgroundColor))
        .fileExporter(
            isPresented: $isShowingBackupFilePicker,
            document: SSHConfigDocument(configContent: formatConfigContent(viewModel: viewModel)),
            contentType: .text,
            defaultFilename: AppConstants.defaultBackupFileName
        ) { result in
            switch result {
            case .success(let url):
                viewModel.backupConfig(to: url)
            case .failure(let error):
                ErrorHandler.handle(error, messageHandler: viewModel.getMessageHandler())
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
                ErrorHandler.handle(error, messageHandler: viewModel.getMessageHandler())
            }
        }
        .loadingOverlay(isLoading: viewModel.getAsyncUtility().isLoading)
        .messageOverlay(messageHandler: viewModel.getMessageHandler())
    }
    
    // 在ContentView中创建一个格式化内容的方法
    private func formatConfigContent(viewModel: SSHConfigViewModel) -> String {
        // 通过Task运行同步代码以获取格式化内容
        let content = viewModel.parser.formatConfig(entries: viewModel.entries)
        return content
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
                        // 移除临时添加的条目
                        if let index = viewModel.entries.firstIndex(where: { $0.id == entry.id }) {
                            viewModel.entries.remove(at: index)
                        }
                        // 使用正式的添加方法
                        viewModel.addEntry(host: editedHost, properties: editedProperties)
                    } else {
                        viewModel.updateEntry(id: entry.id, host: editedHost, properties: editedProperties)
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
