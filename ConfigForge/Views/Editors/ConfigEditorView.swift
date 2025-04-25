import SwiftUI

/// Kubernetes 配置编辑器视图，支持查看和编辑配置文件
struct ConfigEditorView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @StateObject private var viewModel = ConfigEditorViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 编辑器工具栏 - 更新样式与 SSH 一致
            HStack(spacing: 16) {
                Text(viewModel.editorTitle)
                    .font(.title2.bold())
                    .frame(alignment: .leading)
                
                Spacer()
                
                // 简化为编辑/保存按钮，与 SSH 保持一致
                Button(action: {
                    if viewModel.isEditing {
                        viewModel.saveChanges()
                    } else {
                        viewModel.startEditing()
                    }
                }) {
                    Text(viewModel.isEditing ? L10n.App.save : L10n.App.edit)
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(viewModel.isEditing ? "s" : .return, modifiers: .command)
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.large)
                .disabled(!viewModel.isEditing && (viewModel.configFile?.status != .valid || 
                          viewModel.configFile == nil))
            }
            .padding()
            .background(Color(NSColor.textBackgroundColor))
            
            Divider()
            
            // 编辑器内容区域
            if viewModel.configFile == nil {
                EmptyEditorView()
            } else {
                if viewModel.isEditing {
                    TextEditor(text: Binding(
                        get: { viewModel.editorContent },
                        set: { viewModel.updateContent($0) }
                    ))
                    .font(.system(.body, design: .monospaced))
                    .padding(8)
                } else {
                    ScrollView {
                        Text(viewModel.editorContent)
                            .font(.system(.body, design: .monospaced))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                }
            }
        }
        .onChange(of: mainViewModel.selectedConfigFile) { newValue in
            if let configFile = newValue {
                viewModel.loadConfigFile(configFile)
            }
        }
        .onAppear {
            // 初始加载配置文件
            if let configFile = mainViewModel.selectedConfigFile {
                viewModel.loadConfigFile(configFile)
            }
        }
    }
}

/// 配置状态标签
struct ConfigStatusLabel: View {
    let status: KubeConfigFileStatus
    
    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            
            Text(statusText)
                .font(.caption)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .cornerRadius(4)
    }
    
    // 状态图标
    private var statusIcon: some View {
        switch status {
        case .valid:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .invalid:
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        case .unknown:
            return Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.gray)
        }
    }
    
    // 状态文本
    private var statusText: String {
        switch status {
        case .valid:
            return "有效"
        case .invalid(let reason):
            return "无效"
        case .unknown:
            return "未验证"
        }
    }
    
    // 状态颜色
    private var statusColor: Color {
        switch status {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .unknown:
            return .gray
        }
    }
}

/// 空编辑器视图
struct EmptyEditorView: View {
    var body: some View {
        VStack(spacing: 16) {
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
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct ConfigEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigEditorView()
            .environmentObject(MainViewModel())
    }
} 