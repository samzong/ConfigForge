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
        NavigationSplitView {
            // 侧边栏：条目列表
            EntryListView(viewModel: viewModel)
                .frame(minWidth: 200)
        } detail: {
            // 详情视图：编辑器 - 通过id确保在selectedEntry变化时重建视图
            if let selectedEntry = viewModel.selectedEntry {
                EntryEditorView(viewModel: viewModel, entry: selectedEntry)
                    .id(selectedEntry.id) // 确保在selectedEntry变化时重建视图
            } else {
                EmptyEditorView()
            }
        }
        .navigationSplitViewStyle(.balanced) // 确保适当的尺寸比例
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 添加新条目
                    let newEntry = SSHConfigEntry(host: "new-host", properties: [:])
                    viewModel.isEditing = true 
                    viewModel.selectedEntry = newEntry
                }) {
                    Label("添加", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 显示备份文件选择器
                    isShowingBackupFilePicker = true
                }) {
                    Label("备份", systemImage: "arrow.down.doc")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 显示恢复文件选择器
                    isShowingRestoreFilePicker = true
                }) {
                    Label("恢复", systemImage: "arrow.up.doc")
                }
            }
            
            // 添加保存按钮
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    viewModel.saveConfig()
                }) {
                    Label("保存", systemImage: "square.and.arrow.down")
                }
            }
        }
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
                viewModel.setMessage("无法导出备份: \(error.localizedDescription)", type: .error)
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
                viewModel.setMessage("无法导入备份: \(error.localizedDescription)", type: .error)
            }
        }
        .overlay(
            // 使用overlay而不是alert来显示消息
            Group {
                if let message = viewModel.appMessage {
                    MessageBannerView(message: message) {
                        viewModel.appMessage = nil
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.easeInOut, value: viewModel.appMessage != nil)
                }
            }
        )
        .alert(item: Binding(
            get: { viewModel.errorMessage != nil ? ErrorMessage(message: viewModel.errorMessage!) : nil },
            set: { viewModel.errorMessage = $0?.message }
        )) { error in
            Alert(title: Text("错误"), message: Text(error.message), dismissButton: .default(Text("确定")))
        }
    }
}

// 消息横幅视图
struct MessageBannerView: View {
    let message: AppMessage
    let onDismiss: () -> Void
    
    var body: some View {
        VStack {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.white)
                
                Text(message.message)
                    .foregroundColor(.white)
                
                Spacer()
                
                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white)
                }
            }
            .padding()
            .background(bannerColor)
            .cornerRadius(8)
            .padding()
            
            Spacer()
        }
    }
    
    private var iconName: String {
        switch message.type {
        case .success: return "checkmark.circle"
        case .error: return "exclamationmark.triangle"
        case .info: return "info.circle"
        }
    }
    
    private var bannerColor: Color {
        switch message.type {
        case .success: return .green
        case .error: return .red
        case .info: return .blue
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

// 创建这些辅助视图
struct EntryListView: View {
    @ObservedObject var viewModel: SSHConfigViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 分组选择器
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    GroupTab(title: "全部", count: viewModel.entries.count, isSelected: viewModel.selectedGroup == nil) {
                        viewModel.selectedGroup = nil
                    }
                    
                    ForEach(HostGroup.allCases) { group in
                        let count = viewModel.entryCount(forGroup: group)
                        if count > 0 {
                            GroupTab(title: group.rawValue, count: count, isSelected: viewModel.selectedGroup == group) {
                                viewModel.selectedGroup = group
                            }
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
            }
            .background(Color(NSColor.separatorColor).opacity(0.1))
            
            // 主机列表
            List {
                ForEach(viewModel.filteredEntries) { entry in
                    HostRow(entry: entry, isSelected: Binding(
                        get: { viewModel.selectedEntry?.id == entry.id },
                        set: { if $0 { viewModel.selectedEntry = entry } }
                    ), viewModel: viewModel)
                    .contextMenu {
                        // 分组子菜单
                        Menu("移动到...") {
                            Button("全部") {
                                viewModel.setGroup(forEntry: entry.id, group: .other)
                            }
                            
                            Divider()
                            
                            ForEach(HostGroup.allCases) { group in
                                if group != .other {
                                    Button(group.rawValue) {
                                        viewModel.setGroup(forEntry: entry.id, group: group)
                                    }
                                }
                            }
                        }
                        
                        Divider()
                        
                        Button("删除", role: .destructive) {
                            viewModel.deleteEntry(id: entry.id)
                        }
                    }
                }
            }
            .listStyle(SidebarListStyle())
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索主机")
    }
}

// 主机行视图
struct HostRow: View {
    let entry: SSHConfigEntry
    @Binding var isSelected: Bool
    @ObservedObject var viewModel: SSHConfigViewModel
    
    private var hostGroup: HostGroup {
        HostGroup.fromTag(entry.properties["Group"])
    }
    
    var body: some View {
        Button(action: {
            // 直接设置选中的条目
            viewModel.selectedEntry = entry
        }) {
            HStack {
                // 主机图标
                ZStack {
                    Circle()
                        .fill(groupColor.opacity(0.2))
                        .frame(width: 32, height: 32)
                    
                    Image(systemName: groupIcon)
                        .foregroundColor(groupColor)
                }
                
                VStack(alignment: .leading) {
                    Text(entry.host)
                        .fontWeight(.medium)
                    
                    if let hostname = entry.hostname, !hostname.isEmpty {
                        Text(hostname)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                // 显示端口 (如果不是默认22)
                if let port = entry.port, port != "22" {
                    Text(port)
                        .font(.caption)
                        .padding(4)
                        .background(Color.secondary.opacity(0.2))
                        .cornerRadius(4)
                }
            }
            .padding(.vertical, 4)
            .background(viewModel.selectedEntry?.id == entry.id ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(4)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // 根据分组获取颜色
    private var groupColor: Color {
        switch hostGroup {
        case .personal:
            return .orange
        case .work:
            return .blue
        case .development:
            return .green
        case .production:
            return .red
        case .other:
            return .gray
        }
    }
    
    // 根据分组获取图标
    private var groupIcon: String {
        switch hostGroup {
        case .personal:
            return "person.fill"
        case .work:
            return "briefcase.fill"
        case .development:
            return "hammer.fill"
        case .production:
            return "server.rack"
        case .other:
            return "network"
        }
    }
}

// 分组标签页
struct GroupTab: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(title)
                    .fontWeight(isSelected ? .bold : .regular)
                
                Text("\(count)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

struct EmptyEditorView: View {
    var body: some View {
        VStack {
            Text("选择一个条目进行编辑，或添加新条目")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct EntryEditorView: View {
    @ObservedObject var viewModel: SSHConfigViewModel
    var entry: SSHConfigEntry
    @State private var editedHost: String
    @State private var editedProperties: [String: String]
    @State private var hostValid: Bool = true
    
    init(viewModel: SSHConfigViewModel, entry: SSHConfigEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedHost = State(initialValue: entry.host)
        
        // 为新条目添加默认属性
        if entry.properties.isEmpty && entry.host == "new-host" {
            var defaultProperties: [String: String] = [
                "HostName": "",
                "User": "",
                "Port": "22",
                "IdentityFile": ""
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
        VStack(alignment: .leading) {
            // 编辑器控件
            EditorControls(isEditing: $viewModel.isEditing)
            
            // 主机名称编辑
            HostEditor(host: $editedHost, isEditing: viewModel.isEditing)
                .onChange(of: editedHost) { newValue in
                    // 验证主机名
                    let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.*?"))
                    hostValid = newValue.rangeOfCharacter(from: allowedCharacters.inverted) == nil && !newValue.isEmpty
                }
            
            // 属性编辑
            PropertiesEditor(properties: $editedProperties, isEditing: viewModel.isEditing)
            
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem {
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
                .disabled(viewModel.isEditing && (!hostValid || editedHost.isEmpty))
            }
        }
        .id(entry.id)
    }
}

struct PropertyRow: View {
    let key: String
    let value: String
    let isEditable: Bool
    let onValueChanged: (String) -> Void
    
    @State private var editedValue: String
    
    init(key: String, value: String, isEditable: Bool, onValueChanged: @escaping (String) -> Void) {
        self.key = key
        self.value = value
        self.isEditable = isEditable
        self.onValueChanged = onValueChanged
        _editedValue = State(initialValue: value)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(key)
                .font(.headline)
                .foregroundColor(.secondary)
            
            if isEditable {
                TextField(key, text: $editedValue)
                    .onChange(of: editedValue) { newValue in
                        onValueChanged(newValue)
                    }
            } else {
                Text(value)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(8)
    }
}
