import SwiftUI

/// Kubernetes 配置编辑器视图，支持查看和编辑配置文件
struct ConfigEditorView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @StateObject private var viewModel = ConfigEditorViewModel()
    
    var body: some View {
        VStack(spacing: 0) {
            // 编辑器工具栏
            HStack {
                Text(viewModel.editorTitle)
                    .font(.headline)
                
                Spacer()
                
                // 显示配置文件状态
                if let configFile = viewModel.configFile {
                    ConfigStatusLabel(status: configFile.status)
                }
                
                // 编辑器验证状态（当编辑时显示）
                if viewModel.isEditing {
                    ValidationStatusView(state: viewModel.validationState)
                        .transition(.opacity)
                }
                
                // 撤销/重做按钮（仅在编辑模式）
                if viewModel.isEditing {
                    Button(action: {
                        viewModel.undo()
                    }) {
                        Image(systemName: "arrow.uturn.backward")
                    }
                    .buttonStyle(.plain)
                    .help("撤销")
                    .disabled(!viewModel.canUndo)
                    
                    Button(action: {
                        viewModel.redo()
                    }) {
                        Image(systemName: "arrow.uturn.forward")
                    }
                    .buttonStyle(.plain)
                    .help("重做")
                    .disabled(!viewModel.canRedo)
                }
                
                // 编辑模式切换按钮
                Button(action: {
                    toggleEditMode()
                }) {
                    Image(systemName: viewModel.isEditing ? "eye" : "pencil")
                }
                .buttonStyle(.plain)
                .help(viewModel.isEditing ? "切换到查看模式" : "切换到编辑模式")
                .disabled(viewModel.configFile?.status != .valid || 
                          viewModel.configFile == nil)
                
                if viewModel.isEditing {
                    Button(action: {
                        viewModel.saveChanges()
                    }) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.plain)
                    .help("保存更改")
                    
                    Button(action: {
                        viewModel.discardChanges()
                    }) {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.plain)
                    .help("取消编辑")
                }
            }
            .padding(10)
            .background(Color.gray.opacity(0.1))
            
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
    
    // 切换编辑模式
    private func toggleEditMode() {
        if !viewModel.isEditing {
            viewModel.startEditing()
        } else {
            viewModel.stopEditing()
        }
    }
}

/// 验证状态视图
struct ValidationStatusView: View {
    let state: ConfigEditorViewModel.ValidationState
    
    var body: some View {
        HStack(spacing: 4) {
            statusIcon
            
            if case .invalid(let message) = state {
                Text("验证错误")
                    .font(.caption)
                    .onHover { isHovered in
                        if isHovered {
                            NSCursor.pointingHand.set()
                        } else {
                            NSCursor.arrow.set()
                        }
                    }
                    .help(message)
            } else if case .validating = state {
                Text("验证中...")
                    .font(.caption)
            } else if case .valid = state {
                Text("有效")
                    .font(.caption)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(statusColor.opacity(0.2))
        .foregroundColor(statusColor)
        .cornerRadius(4)
    }
    
    // 状态图标
    private var statusIcon: some View {
        switch state {
        case .valid:
            return Image(systemName: "checkmark.circle.fill")
        case .invalid:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .validating:
            return Image(systemName: "clock.fill")
        case .notValidated:
            return Image(systemName: "questionmark.circle.fill")
        }
    }
    
    // 状态颜色
    private var statusColor: Color {
        switch state {
        case .valid:
            return .green
        case .invalid:
            return .red
        case .validating:
            return .orange
        case .notValidated:
            return .gray
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
        case .invalid:
            return Image(systemName: "exclamationmark.triangle.fill")
        case .unknown:
            return Image(systemName: "questionmark.circle.fill")
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
            Image(systemName: "doc.text")
                .resizable()
                .scaledToFit()
                .frame(width: 60, height: 60)
                .foregroundColor(.gray)
            
            Text("未选择配置文件")
                .font(.headline)
            
            Text("从左侧列表中选择一个配置文件进行查看或编辑。")
                .font(.subheadline)
                .foregroundColor(.gray)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct ConfigEditorView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigEditorView()
            .environmentObject(MainViewModel())
    }
} 