//
//  ContentView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = SSHConfigViewModel()
    
    var body: some View {
        NavigationSplitView {
            // 侧边栏：条目列表
            EntryListView(viewModel: viewModel)
        } detail: {
            // 详情视图：编辑器
            if let selectedEntry = viewModel.selectedEntry {
                EntryEditorView(viewModel: viewModel, entry: selectedEntry)
            } else {
                EmptyEditorView()
            }
        }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 添加新条目
                    let newEntry = SSHConfigEntry(host: "new-host", properties: [:])
                    viewModel.selectedEntry = newEntry
                    viewModel.isEditing = true
                }) {
                    Label("添加", systemImage: "plus")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 执行备份
                    viewModel.backupConfig(to: nil)
                }) {
                    Label("备份", systemImage: "arrow.down.doc")
                }
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button(action: {
                    // 显示恢复文件选择器
                    // 这需要实现一个文件选择器
                }) {
                    Label("恢复", systemImage: "arrow.up.doc")
                }
            }
        }
        .alert(item: Binding(
            get: { viewModel.errorMessage != nil ? viewModel.errorMessage : nil },
            set: { viewModel.errorMessage = $0 }
        )) { message in
            Alert(title: Text("错误"), message: Text(message), dismissButton: .default(Text("确定")))
        }
    }
}

// 创建这些辅助视图
struct EntryListView: View {
    @ObservedObject var viewModel: SSHConfigViewModel
    
    var body: some View {
        List(viewModel.filteredEntries, selection: $viewModel.selectedEntry) { entry in
            Text(entry.host)
                .contextMenu {
                    Button("删除", role: .destructive) {
                        viewModel.deleteEntry(id: entry.id)
                    }
                }
        }
        .searchable(text: $viewModel.searchText, prompt: "搜索 Host")
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
    
    init(viewModel: SSHConfigViewModel, entry: SSHConfigEntry) {
        self.viewModel = viewModel
        self.entry = entry
        _editedHost = State(initialValue: entry.host)
        _editedProperties = State(initialValue: entry.properties)
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            TextField("Host", text: $editedHost)
                .font(.title)
                .padding(.bottom)
                .disabled(!viewModel.isEditing)
            
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(editedProperties.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        PropertyRow(key: key, value: value, isEditable: viewModel.isEditing) { newValue in
                            editedProperties[key] = newValue
                        }
                    }
                    
                    if viewModel.isEditing {
                        Button("添加属性") {
                            // 这里可以弹出一个添加属性的对话框
                            editedProperties["NewProperty"] = ""
                        }
                        .padding(.top)
                    }
                }
                .padding()
            }
            
            Spacer()
        }
        .padding()
        .toolbar {
            ToolbarItem {
                Button(viewModel.isEditing ? "保存" : "编辑") {
                    if viewModel.isEditing {
                        // 保存编辑
                        if entry.id == UUID() { // 新条目
                            viewModel.addEntry(host: editedHost, properties: editedProperties)
                        } else {
                            viewModel.updateEntry(id: entry.id, host: editedHost, properties: editedProperties)
                        }
                    }
                    viewModel.isEditing.toggle()
                }
            }
        }
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
