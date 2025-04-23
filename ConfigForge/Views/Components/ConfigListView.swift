import SwiftUI

/// 配置文件列表视图，显示所有发现的 Kubernetes 配置文件
struct ConfigListView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("配置文件")
                    .font(.headline)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    viewModel.refreshKubeConfigFiles()
                }) {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .padding(.trailing)
                .help("刷新配置文件列表")
            }
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.gray)
                
                TextField("搜索配置文件", text: $viewModel.configSearchText)
                    .textFieldStyle(PlainTextFieldStyle())
                
                if !viewModel.configSearchText.isEmpty {
                    Button(action: {
                        viewModel.configSearchText = ""
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(8)
            .background(Color.gray.opacity(0.1))
            
            if viewModel.isLoadingConfigFiles {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                if viewModel.displayedConfigFiles.isEmpty {
                    EmptyConfigView(viewModel: viewModel)
                } else {
                    // 配置文件列表
                    List(viewModel.displayedConfigFiles, id: \.id) { configFile in
                        ConfigFileRow(configFile: configFile, 
                                     isSelected: viewModel.selectedConfigFile?.id == configFile.id,
                                     isActive: configFile.fileType == .active)
                            .onTapGesture {
                                viewModel.selectConfigFile(configFile)
                            }
                            .contextMenu {
                                ConfigFileContextMenu(viewModel: viewModel, configFile: configFile)
                            }
                    }
                    .listStyle(PlainListStyle())
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
        HStack {
            // 状态图标
            statusIcon
                .frame(width: 20)
            
            // 文件名
            Text(configFile.displayName)
                .lineLimit(1)
            
            Spacer()
            
            // 如果是活动配置，显示活动标记
            if isActive {
                Text("活动")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.blue.opacity(0.2))
                    .foregroundColor(.blue)
                    .cornerRadius(4)
            }
            
            // 如果是备份，显示备份标记
            if configFile.fileType == .backup {
                Text("备份")
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.2))
                    .foregroundColor(.orange)
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
    }
    
    // 状态图标根据配置文件状态显示不同图标
    private var statusIcon: some View {
        Group {
            switch configFile.status {
            case .valid:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .invalid:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .unknown:
                Image(systemName: "questionmark.circle.fill")
                    .foregroundColor(.gray)
            }
        }
    }
}

/// 配置文件上下文菜单
struct ConfigFileContextMenu: View {
    @ObservedObject var viewModel: MainViewModel
    let configFile: KubeConfigFile
    
    var body: some View {
        Button(action: {
            viewModel.activateConfigFile(configFile)
        }) {
            Text("设为活动配置")
            Image(systemName: "checkmark.circle")
        }
        .disabled(configFile.fileType == .active || configFile.status != .valid)
        
        Divider()
        
        Button(action: {
            viewModel.duplicateConfigFile(configFile)
        }) {
            Text("复制")
            Image(systemName: "doc.on.doc")
        }
        
        Button(action: {
            viewModel.promptForRenameConfigFile(configFile)
        }) {
            Text("重命名")
            Image(systemName: "pencil")
        }
        .disabled(configFile.fileType == .active || configFile.fileType == .backup)
        
        Divider()
        
        Button(action: {
            viewModel.promptForDeleteConfigFile(configFile)
        }) {
            Text("删除")
            Image(systemName: "trash")
        }
        .disabled(configFile.fileType == .active || configFile.fileType == .backup)
    }
}

/// 空状态视图，当没有配置文件时显示
struct EmptyConfigView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
            
            Text("没有找到配置文件")
                .font(.headline)
            
            Text("在 ~/.kube/configs/ 目录中创建配置文件，或者从这里创建一个新的配置。")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
            
            Button("创建新配置") {
                viewModel.createNewConfigFile()
            }
            .buttonStyle(.bordered)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfigListView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigListView(viewModel: MainViewModel())
            .frame(width: 300, height: 500)
    }
} 