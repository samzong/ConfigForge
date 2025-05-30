import SwiftUI

struct ConfigEditorView: View {
    @EnvironmentObject var mainViewModel: MainViewModel
    @StateObject private var viewModel = ConfigEditorViewModel()

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(viewModel.editorTitle)
                    .font(.title2.bold())
                    .frame(alignment: .leading)

                Spacer()
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
            if let configFile = mainViewModel.selectedConfigFile {
                viewModel.loadConfigFile(configFile)
            }
        }
    }
}

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

    private var statusIcon: some View {
        switch status {
        case .valid:
            return Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
        case .invalid(_):
            return Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
        case .unknown:
            return Image(systemName: "questionmark.circle.fill")
                .foregroundColor(.gray)
        }
    }

    private var statusText: String {
        switch status {
        case .valid:
            return "有效"
        case .invalid(_):
            return "无效"
        case .unknown:
            return "未验证"
        }
    }

    private var statusColor: Color {
        switch status {
        case .valid:
            return .green
        case .invalid(_):
            return .red
        case .unknown:
            return .gray
        }
    }
}

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