//
//  SidebarView.swift
//  ConfigForge
//
//  Created by samzong
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
            
            // 搜索区域
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
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
            }
            .padding(8)
            .background(Color(NSColor.textBackgroundColor))
            .cornerRadius(8)
            .padding([.horizontal, .top], 8)
            
            // ---- Secondary Kubernetes Picker (Contexts/Clusters/Users) ----
            if viewModel.selectedConfigurationType == .kubernetes {
                Picker("", selection: $viewModel.selectedKubernetesObjectType) {
                    ForEach(KubeObjectType.allCases) { type in
                        Text(NSLocalizedString(type.rawValue, bundle: .main, comment: "")).tag(type)
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
                                     Label(L10n.App.delete, systemImage: "trash")
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
                                     Label(L10n.App.delete, systemImage: "trash")
                                 }
                             }
                             .onTapGesture {
                                 handleItemTapGesture(entry: kubeContext)
                             }
                     } else if let kubeCluster = entry as? KubeCluster {
                         // 使用简单的行视图显示，而不是在边栏嵌入编辑器
                         KubeClusterRowView(cluster: kubeCluster)
                             .tag(kubeCluster.id as AnyHashable)
                             .contextMenu {
                                 Button(role: .destructive) {
                                     viewModel.deleteKubeCluster(id: kubeCluster.id)
                                 } label: {
                                     Label(L10n.App.delete, systemImage: "trash")
                                 }
                             }
                             .onTapGesture {
                                 handleItemTapGesture(entry: kubeCluster)
                             }
                     } else if let kubeUser = entry as? KubeUser {
                         KubeUserRowView(user: kubeUser) // Use existing Row View
                             .tag(kubeUser.id as AnyHashable)
                             .contextMenu {
                                  Button(role: .destructive) {
                                     viewModel.deleteKubeUser(id: kubeUser.id)
                                 } label: {
                                     Label(L10n.App.delete, systemImage: "trash")
                                 }
                             }
                             .onTapGesture {
                                 handleItemTapGesture(entry: kubeUser)
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
                    let newHostString = L10n.Host.new
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
    private func addButtoText() -> String {
        switch viewModel.selectedConfigurationType {
        case .ssh:
            return L10n.Sidebar.Add.host
        case .kubernetes:
            switch viewModel.selectedKubernetesObjectType {
            case .contexts: return L10n.Sidebar.Add.context
            case .clusters: return L10n.Sidebar.Add.cluster
            case .users: return L10n.Sidebar.Add.user
            }
        }
    }
} 