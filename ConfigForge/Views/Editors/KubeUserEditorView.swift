import SwiftUI

struct KubeUserEditorView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var user: KubeUser
    
    // 本地编辑状态
    @State private var editedName: String
    @State private var editedClientCert: String
    @State private var editedClientKey: String
    @State private var isEditing: Bool = false // 添加编辑状态
    @State private var isNameValid: Bool = true
    
    init(viewModel: MainViewModel, user: Binding<KubeUser>) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._user = user
        
        // 初始化本地状态
        _editedName = State(initialValue: user.wrappedValue.name)
        _editedClientCert = State(initialValue: user.wrappedValue.user.clientCertificateData ?? "")
        _editedClientKey = State(initialValue: user.wrappedValue.user.clientKeyData ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 顶部标题和编辑按钮
            HStack {
                Text(L10n.Kubernetes.User.edit(user.name))
                    .font(.title2.bold())
                Spacer()
                
                // 添加编辑/保存按钮
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // 如果正在编辑状态，点击保存更改
                        if isEditing {
                            saveChanges()
                        }
                        // 切换编辑状态
                        isEditing.toggle()
                    }
                }) {
                    Text(isEditing ? L10n.App.save : L10n.App.edit)
                        .frame(minWidth: 80)
                }
                .keyboardShortcut(.return, modifiers: .command)
                .buttonStyle(BorderedButtonStyle())
                .controlSize(.large)
            }
            Divider()
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // User 名称
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.Kubernetes.User.name, systemImage: "person.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isEditing {
                            TextField(L10n.Kubernetes.User.name, text: $editedName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                                .onChange(of: editedName) { newValue in
                                    isNameValid = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                                }
                        } else {
                            Text(user.name)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    // 认证方式部分
                    authenticationSection
                }
                .padding(.vertical)
                .padding(.horizontal, 8)
            }
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .onChange(of: user) { newUser in
            if !isEditing {
                editedName = newUser.name
                editedClientCert = newUser.user.clientCertificateData ?? ""
                editedClientKey = newUser.user.clientKeyData ?? ""
            }
        }
        .onAppear {
            editedName = user.name
            editedClientCert = user.user.clientCertificateData ?? ""
            editedClientKey = user.user.clientKeyData ?? ""
        }
    }
    
    private var authenticationSection: some View {
        Group {
            // 证书认证
            VStack(alignment: .leading, spacing: 8) {
                Label(L10n.Kubernetes.User.Cert.auth, systemImage: "shield.fill")
                    .font(.headline)
                    .foregroundColor(.primary)
                
                // 客户端证书
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Kubernetes.User.Client.cert)
                        .font(.subheadline)
                    
                    if isEditing {
                        TextEditor(text: $editedClientCert)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                    } else {
                        ScrollView {
                            Text(editedClientCert.isEmpty ? L10n.Kubernetes.User.Client.Cert.empty : editedClientCert)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
                
                // 客户端密钥
                VStack(alignment: .leading, spacing: 8) {
                    Text(L10n.Kubernetes.User.Client.key)
                        .font(.subheadline)
                    
                    if isEditing {
                        TextEditor(text: $editedClientKey)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 100)
                            .padding(4)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                            )
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                    } else {
                        ScrollView {
                            Text(editedClientKey.isEmpty ? L10n.Kubernetes.User.Client.Key.empty : editedClientKey)
                                .font(.system(.body, design: .monospaced))
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 100)
                        .padding()
                        .background(Color.secondary.opacity(0.05))
                        .cornerRadius(8)
                    }
                }
            }
        }
    }
    
    // 保存更改方法
    private func saveChanges() {
        // 验证名称不为空
        if editedName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.postMessage("错误：用户名称不能为空", type: .error)
            return
        }
        
        // 直接更新绑定的user对象
        user.name = editedName
        user.user = UserDetails(
            clientCertificateData: editedClientCert.isEmpty ? nil : editedClientCert,
            clientKeyData: editedClientKey.isEmpty ? nil : editedClientKey,
            token: nil
        )
        
        // 通知用户更新成功
        viewModel.postMessage("用户信息已更新", type: .success)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var previewViewModel = MainViewModel()
        @State var previewUser = KubeUser(
            name: "preview-user",
            user: UserDetails(
                clientCertificateData: "LS0t...",
                clientKeyData: "LS0t...",
                token: nil
            )
        )
        
        var body: some View {
            KubeUserEditorView(viewModel: previewViewModel, user: $previewUser)
        }
    }
    return PreviewWrapper()
        .frame(width: 400, height: 800)
} 