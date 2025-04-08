import SwiftUI

struct UserDetailView: View {
    // 属性
    @ObservedObject var viewModel: MainViewModel
    let user: KubeUser
    
    // 本地编辑状态
    @State private var editedToken: String
    @State private var editedClientCertData: String
    @State private var editedClientKeyData: String
    
    // 关闭面板的动作（从父级传递）
    var onClose: () -> Void
    
    // 初始化方法
    init(viewModel: MainViewModel, user: KubeUser, onClose: @escaping () -> Void) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.user = user
        self.onClose = onClose
        
        // 初始化本地状态
        _editedToken = State(initialValue: user.user.token ?? "")
        _editedClientCertData = State(initialValue: user.user.clientCertificateData ?? "")
        _editedClientKeyData = State(initialValue: user.user.clientKeyData ?? "")
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("kubernetes.user.details.title".localized(user.name))
                    .font(.title2.bold())
                Spacer()
                Button("button.done".localized, action: onClose) // 关闭按钮
            }
            Divider().padding(.bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("kubernetes.user.name.label".localized).bold().frame(width: 100, alignment: .trailing)
                        Text(user.name)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("kubernetes.user.token.label".localized).bold()
                        TextEditor(text: $editedToken)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 80)
                            .border(Color.gray.opacity(0.5), width: 1)
                            .disableAutocorrection(true)
                            .onChange(of: editedToken) { newValue in
                                // 更新视图模型中的数据
                                if let index = viewModel.kubeUsers.firstIndex(where: { $0.id == user.id }) {
                                    viewModel.kubeUsers[index].user.token = newValue.isEmpty ? nil : newValue
                                    viewModel.kubeConfig?.users = viewModel.kubeUsers
                                    viewModel.saveKubeConfig()
                                }
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("kubernetes.user.client.cert.label".localized).bold()
                        TextEditor(text: $editedClientCertData)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.5), width: 1)
                            .disableAutocorrection(true)
                            .onChange(of: editedClientCertData) { newValue in
                                // 更新视图模型中的数据
                                if let index = viewModel.kubeUsers.firstIndex(where: { $0.id == user.id }) {
                                    viewModel.kubeUsers[index].user.clientCertificateData = newValue.isEmpty ? nil : newValue
                                    viewModel.kubeConfig?.users = viewModel.kubeUsers
                                    viewModel.saveKubeConfig()
                                }
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("kubernetes.user.client.key.label".localized).bold()
                        TextEditor(text: $editedClientKeyData)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.5), width: 1)
                            .disableAutocorrection(true)
                            .onChange(of: editedClientKeyData) { newValue in
                                // 更新视图模型中的数据
                                if let index = viewModel.kubeUsers.firstIndex(where: { $0.id == user.id }) {
                                    viewModel.kubeUsers[index].user.clientKeyData = newValue.isEmpty ? nil : newValue
                                    viewModel.kubeConfig?.users = viewModel.kubeUsers
                                    viewModel.saveKubeConfig()
                                }
                            }
                    }
                }
                .padding(.vertical)
            }

            Spacer() // 将内容推向顶部
        }
        .padding()
        .frame(idealWidth: 400) // 建议理想宽度
        .frame(maxHeight: .infinity, alignment: .topLeading)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var previewViewModel = MainViewModel()
        let previewUser = KubeUser(
            name: "preview-user",
            user: UserDetails(
                clientCertificateData: "LS0tLS1...",
                clientKeyData: "LS0tLS1...",
                token: "eyJhbG..."
            )
        )

        var body: some View {
            UserDetailView(
                viewModel: previewViewModel,
                user: previewUser,
                onClose: { print("Close panel") }
            )
        }
    }
    return PreviewWrapper()
        .frame(width: 400, height: 600)
} 