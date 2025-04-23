import SwiftUI

struct KubeClusterEditorView: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var cluster: KubeCluster

    // 本地编辑状态
    @State private var editedName: String
    @State private var editedServer: String
    @State private var editedCaData: String
    @State private var editedSkipTls: Bool
    @State private var isEditing: Bool = false // 添加编辑状态
    @State private var isNameValid: Bool = true

    init(viewModel: MainViewModel, cluster: Binding<KubeCluster>) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self._cluster = cluster
        // 初始化本地状态
        _editedName = State(initialValue: cluster.wrappedValue.name)
        _editedServer = State(initialValue: cluster.wrappedValue.cluster.server)
        _editedCaData = State(initialValue: cluster.wrappedValue.cluster.certificateAuthorityData ?? "")
        _editedSkipTls = State(initialValue: cluster.wrappedValue.cluster.insecureSkipTlsVerify ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 顶部标题和编辑按钮
            HStack {
                Text(L10n.Kubernetes.Cluster.edit(cluster.name))
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
                    // 集群名称（可编辑）
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.Kubernetes.Cluster.name, systemImage: "tag.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isEditing {
                            TextField(L10n.Kubernetes.Cluster.name, text: $editedName)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                                .onChange(of: editedName) { newValue in
                                    isNameValid = !newValue.trimmingCharacters(in: .whitespaces).isEmpty
                                }
                        } else {
                            Text(cluster.name)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }
                    
                    // 服务器 URL
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.Kubernetes.Cluster.server, systemImage: "network")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isEditing {
                            TextField(L10n.Kubernetes.Cluster.Server.placeholder, text: $editedServer)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .padding()
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                        } else {
                            Text(editedServer)
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                        }
                    }

                    // 证书数据
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.Kubernetes.Cluster.ca, systemImage: "shield.fill")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isEditing {
                            TextEditor(text: $editedCaData)
                                .font(.system(.body, design: .monospaced))
                                .frame(height: 150)
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
                                Text(editedCaData.isEmpty ? L10n.Kubernetes.Cluster.Ca.empty : editedCaData)
                                    .font(.system(.body, design: .monospaced))
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .frame(height: 150)
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }

                    // TLS验证选项
                    VStack(alignment: .leading, spacing: 8) {
                        Label(L10n.Kubernetes.Cluster.security, systemImage: "lock.shield")
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        if isEditing {
                            Toggle(L10n.Kubernetes.Cluster.Skip.tls, isOn: $editedSkipTls)
                                .padding()
                                .background(Color.secondary.opacity(0.05))
                                .cornerRadius(8)
                        } else {
                            HStack {
                                Text(L10n.Kubernetes.Cluster.Skip.tls)
                                Spacer()
                                Image(systemName: editedSkipTls ? "checkmark.square" : "square")
                            }
                            .padding()
                            .background(Color.secondary.opacity(0.05))
                            .cornerRadius(8)
                        }
                    }
                }
                .padding(.vertical)
                .padding(.horizontal, 8)
            }
            .frame(maxWidth: .infinity)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .onChange(of: cluster) { newCluster in
            if !isEditing {
                editedName = newCluster.name
                editedServer = newCluster.cluster.server
                editedCaData = newCluster.cluster.certificateAuthorityData ?? ""
                editedSkipTls = newCluster.cluster.insecureSkipTlsVerify ?? false
            }
        }
        .onAppear {
            editedName = cluster.name
            editedServer = cluster.cluster.server
            editedCaData = cluster.cluster.certificateAuthorityData ?? ""
            editedSkipTls = cluster.cluster.insecureSkipTlsVerify ?? false
        }
    }
    
    // 保存更改方法
    private func saveChanges() {
        // 验证名称不为空
        if editedName.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.postMessage("错误：集群名称不能为空", type: .error)
            return
        }
        
        // 验证服务器URL不为空
        if editedServer.trimmingCharacters(in: .whitespaces).isEmpty {
            viewModel.postMessage("错误：服务器URL不能为空", type: .error)
            return
        }
        
        // 直接更新绑定的 cluster 对象
        cluster.name = editedName
        cluster.cluster = ClusterDetails(
            server: editedServer,
            certificateAuthorityData: editedCaData.isEmpty ? nil : editedCaData,
            insecureSkipTlsVerify: editedSkipTls
        )
        
        // 通知用户更新成功
        viewModel.postMessage("集群信息已更新", type: .success)
    }
}

#Preview {
    struct PreviewWrapper: View {
        @StateObject var previewViewModel = MainViewModel()
        @State var previewCluster = KubeCluster(
            name: "preview-cluster",
            cluster: ClusterDetails(
                server: "https://preview.server.com",
                certificateAuthorityData: "LS0t...",
                insecureSkipTlsVerify: nil as Bool?
            )
        )

        var body: some View {
            KubeClusterEditorView(viewModel: previewViewModel, cluster: $previewCluster)
        }
    }
    return PreviewWrapper()
        .frame(width: 400, height: 500)
} 
