//
//  SidebarView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct SidebarView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedListIndex: Int?
    
    var body: some View {
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
                
                // 仅在SSH模式下显示顶部保存按钮，Kubernetes模式使用编辑器内的按钮
                if viewModel.selectedConfigurationType == .ssh {
                    // 保存按钮
                    Button(action: {
                        viewModel.saveCurrentConfig()
                    }) {
                        Text(L10n.App.save)
                    }
                    .buttonStyle(BorderedButtonStyle())
                    .controlSize(.small)
                    .keyboardShortcut("s", modifiers: .command)
                    .help(L10n.App.Save.help)
                }
            }
            .padding([.horizontal, .top], 12)
            .padding(.bottom, 4)
            
            // ---- Top Navigation Picker (SSH / Kubernetes) ----
            Picker("", selection: $viewModel.selectedConfigurationType) {
                ForEach(ConfigType.allCases) { type in
                    Text(NSLocalizedString(type.rawValue, bundle: .main, comment: "")).tag(type)
                }
            }
            .pickerStyle(.segmented) // Use segmented style for top level
            .padding(.horizontal, 12)
            .padding(.bottom, 8)
            // ---- End Top Navigation Picker ----
            
            // 统一的搜索区域 - 根据当前选择的配置类型绑定不同的搜索文本
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                
                // 根据当前模式动态绑定搜索文本
                if viewModel.selectedConfigurationType == .ssh {
                    TextField(L10n.Sidebar.search, text: $viewModel.searchText)
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
                } else {
                    // Kubernetes 模式下的搜索
                    TextField(L10n.Kubernetes.search, text: $viewModel.configSearchText)
                        .textFieldStyle(PlainTextFieldStyle())
                    
                    if !viewModel.configSearchText.isEmpty {
                        Button(action: {
                            viewModel.configSearchText = ""
                        }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding([.horizontal, .top], 8)
            
            // SSH 模式显示主机列表
            if viewModel.selectedConfigurationType == .ssh {
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
                                        Label(L10n.App.delete, systemImage: "trash")
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
            } 
            // Kubernetes 模式显示配置文件列表
            else if viewModel.selectedConfigurationType == .kubernetes {
                // 内嵌 ConfigListView
                ConfigListView(viewModel: viewModel)
            }
            
            Divider()
            
            // 底部添加按钮
            Button(action: {
                switch viewModel.selectedConfigurationType {
                case .ssh:
                    // Existing SSH add logic
                    let newHostString = L10n.Host.new
                    let newEntry = SSHConfigEntry(host: newHostString, directives: [])
                    viewModel.sshEntries.append(newEntry) // Add to sshEntries
                    viewModel.safelySelectEntry(newEntry)

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.isEditing = true
                        }
                    }

                case .kubernetes:
                    // 创建新的 Kubernetes 配置文件
                    viewModel.createNewConfigFile()
                }
            }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text(addButtonText()) 
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
    
    // Extracted reusable function to handle item tap gestures
    private func handleItemTapGesture<T: Identifiable>(entry: T) {
        // 强制刷新选择，即使是点击当前已选中的项目
        let currentlySelectedId = viewModel.selectedEntry?.id as? String
        if currentlySelectedId == entry.id as? String {
            // 如果点击当前选中项，先取消选择再重新选择，强制刷新
            viewModel.safelySelectEntry(nil)
            DispatchQueue.main.async {
                viewModel.safelySelectEntry(entry)
            }
        } else {
            viewModel.safelySelectEntry(entry)
        }
    }
    
    // Helper function for dynamic Add button text
    private func addButtonText() -> String {
        switch viewModel.selectedConfigurationType {
        case .ssh:
            return L10n.Sidebar.Add.host
        case .kubernetes:
            return L10n.Sidebar.Add.config
        }
    }
} 