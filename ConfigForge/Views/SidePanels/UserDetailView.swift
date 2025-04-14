import SwiftUI

struct UserDetailView: View {
    // 用户对象
    let user: KubeUser
    // 编辑状态
    @State private var editedToken: String
    @State private var editedClientCert: String
    @State private var editedClientKey: String
    
    // 关闭回调
    let onClose: () -> Void
    
    init(user: KubeUser, onClose: @escaping () -> Void) {
        self.user = user
        self.onClose = onClose
        _editedToken = State(initialValue: user.user.token ?? "")
        _editedClientCert = State(initialValue: user.user.clientCertificateData ?? "")
        _editedClientKey = State(initialValue: user.user.clientKeyData ?? "")
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text(L10n.Kubernetes.User.Details.title(user.name))
                    .font(.title2)
                Spacer()
                Button(L10n.Button.done, action: onClose) // 关闭按钮
            }
            .padding(.bottom, 8)
            
            // 用户名称
            HStack {
                Text(L10n.Kubernetes.User.Name.label).bold().frame(width: 100, alignment: .trailing)
                Text(user.name)
                    .foregroundColor(.primary)
            }
            
            // Token
            VStack(alignment: .leading) {
                Text(L10n.Kubernetes.User.Token.label).bold()
                
                if editedToken.isEmpty {
                    Text(L10n.Kubernetes.User.Token.empty)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
                } else {
                    TextEditor(text: $editedToken)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 60)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(true) // 只读模式
                }
            }
            
            // 客户端证书
            VStack(alignment: .leading) {
                Text(L10n.Kubernetes.User.Client.Cert.label).bold()
                
                if editedClientCert.isEmpty {
                    Text(L10n.Kubernetes.User.Client.Cert.empty)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
                } else {
                    TextEditor(text: $editedClientCert)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(true) // 只读模式
                }
            }
            
            // 客户端密钥
            VStack(alignment: .leading) {
                Text(L10n.Kubernetes.User.Client.Key.label).bold()
                
                if editedClientKey.isEmpty {
                    Text(L10n.Kubernetes.User.Client.Key.empty)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding(.top, 4)
                } else {
                    TextEditor(text: $editedClientKey)
                        .font(.system(.body, design: .monospaced))
                        .frame(height: 100)
                        .padding(4)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                        )
                        .disabled(true) // 只读模式
                }
            }
                
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 500)
    }
}

#Preview {
    struct PreviewWrapper: View {
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
                user: previewUser,
                onClose: { print("Close panel") }
            )
        }
    }
    return PreviewWrapper()
        .frame(width: 400, height: 600)
} 