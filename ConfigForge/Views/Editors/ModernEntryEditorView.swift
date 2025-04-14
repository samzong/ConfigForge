//
//  ModernEntryEditorView.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI
import AppKit

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
        let newHostString = L10n.Host.new
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
                        label: L10n.Property.hostname,
                        systemImage: "network",
                        value: Binding(
                            get: { editedProperties["HostName"] ?? "" },
                            set: { editedProperties["HostName"] = $0 }
                        ),
                        placeholder: L10n.Property.Hostname.placeholder
                    )
                    
                    // 用户名配置项
                    configPropertyView(
                        label: L10n.Property.user,
                        systemImage: "person.fill",
                        value: Binding(
                            get: { editedProperties["User"] ?? "" },
                            set: { editedProperties["User"] = $0 }
                        ),
                        placeholder: L10n.Property.User.placeholder
                    )
                    
                    // 端口配置项
                    configPropertyView(
                        label: L10n.Property.port,
                        systemImage: "number.circle",
                        value: Binding(
                            get: { editedProperties["Port"] ?? "22" },
                            set: { editedProperties["Port"] = $0 }
                        ),
                        placeholder: L10n.Property.Port.placeholder
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
            Label(L10n.Property.identityfile, systemImage: "key.fill")
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
                        TextField(L10n.Property.Identityfile.placeholder, text: Binding(
                            get: { editedProperties["IdentityFile"] ?? "" },
                            set: { editedProperties["IdentityFile"] = $0 }
                        ))
                        .textFieldStyle(PlainTextFieldStyle())
                        .padding(.horizontal, 6)
                        .padding(.vertical, 4)
                    } else {
                        // 非编辑状态下的Text
                        let value = editedProperties["IdentityFile"] ?? ""
                        Text(value.isEmpty ? L10n.Property.Identityfile.placeholder : value)
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
                    let newHostString = L10n.Host.new
                    
                    // 编辑状态时显示TextField
                    if viewModel.isEditing {
                        TextField(L10n.Host.Enter.name, text: $editedHost)
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
            
            // Add the terminal launcher button when not in editing mode
            if !viewModel.isEditing {
                HStack {
                    TerminalLauncherButton(sshEntry: entry)
                        .frame(height: 32)
                        .padding(.vertical, 8)
                }
                .padding(.top, 8)
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
                    let newHostString = L10n.Host.new
                    
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
                Text(viewModel.isEditing ? L10n.App.save : L10n.App.edit)
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