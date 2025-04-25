import SwiftUI

/// 配置文件列表视图，显示所有发现的 Kubernetes 配置文件
struct ConfigListView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedConfigFileIndex: Int?
    
    var body: some View {
        VStack(spacing: 0) {
            // 移除了标题栏
            // 移除了搜索框，使用 SidebarView 中的通用搜索框
            
            if viewModel.isLoadingConfigFiles {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if viewModel.displayedConfigFiles.isEmpty {
                    EmptyConfigView(viewModel: viewModel)
                } else {
                    // 配置文件列表 - 使用 .sidebar 样式与 SSH 一致
                    List(viewModel.displayedConfigFiles.indices, id: \.self, selection: $selectedConfigFileIndex) { index in
                        if index < viewModel.displayedConfigFiles.count {
                            let configFile = viewModel.displayedConfigFiles[index]
                            
                            ConfigFileRow(configFile: configFile, 
                                         isSelected: viewModel.selectedConfigFile?.id == configFile.id,
                                         isActive: configFile.fileType == .active)
                                .tag(configFile.id as AnyHashable)
                                .contextMenu {
                                    // 保持与 SSH 一致的上下文菜单样式
                                    Button(action: {
                                        viewModel.activateConfigFile(configFile)
                                    }) {
                                        Label(L10n.Kubernetes.Config.setActive, systemImage: "checkmark.circle")
                                    }
                                    .disabled(configFile.fileType == .active || configFile.status != .valid)
                                    
                                    Divider()
                                    
                                    // 已移除重命名选项，与 SSH 行为保持一致
                                    
                                    Button(role: .destructive, action: {
                                        viewModel.promptForDeleteConfigFile(configFile)
                                    }) {
                                        Label(L10n.App.delete, systemImage: "trash")
                                    }
                                    .disabled(configFile.fileType == .active || configFile.fileType == .backup)
                                }
                        } else {
                            Text("Loading...")
                        }
                    }
                    .listStyle(.sidebar)
                    .onChange(of: selectedConfigFileIndex) { newIndex in
                        // 与 SSH 使用相同的选择逻辑
                        if let index = newIndex, index >= 0 && index < viewModel.displayedConfigFiles.count {
                            let configFile = viewModel.displayedConfigFiles[index]
                            viewModel.selectConfigFile(configFile)
                        }
                    }
                    // 与 SSH 一致的视觉样式
                }
            }
        }
    }
}

/// 单个配置文件行
struct ConfigFileRow: View {
    let configFile: KubeConfigFile
    let isSelected: Bool
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // 主要内容与 HostRowView 保持一致的风格
            Text(configFile.displayName)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            // 次要内容也与 HostRowView 一致
            HStack(spacing: 4) {
                // 只有活跃的配置文件显示勾选标记
                if configFile.fileType == .active {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 10))
                } else if case .invalid = configFile.status {
                    // 无效的配置文件显示警告图标
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.system(size: 10))
                }
                
                Text(statusText)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusText: String {
        if configFile.fileType == .active {
            return L10n.Kubernetes.Config.active
        } else if configFile.fileType == .backup {
            return L10n.Kubernetes.Config.backup
        } else {
            return configFile.filePath.path
        }
    }
}

/// 空状态视图，当没有配置文件时显示
struct EmptyConfigView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 10)
            
            Text(L10n.Kubernetes.noSelection)
                .font(.title3)
                .foregroundColor(.primary)
            
            Text(L10n.Kubernetes.selectOrCreate)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
            
            Button(L10n.Kubernetes.createNew) {
                viewModel.createNewConfigFile()
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct ConfigListView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigListView(viewModel: MainViewModel())
            .frame(width: 300, height: 500)
    }
} 