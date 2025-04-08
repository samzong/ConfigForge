import SwiftUI

struct ClusterDetailView: View {
    // 属性
    @ObservedObject var viewModel: MainViewModel
    let cluster: KubeCluster
    
    // 本地编辑状态
    @State private var editedServer: String
    @State private var editedCaData: String
    @State private var editedSkipTls: Bool
    
    // 关闭面板的动作（从父级传递）
    var onClose: () -> Void
    
    // 初始化方法
    init(viewModel: MainViewModel, cluster: KubeCluster, onClose: @escaping () -> Void) {
        self._viewModel = ObservedObject(wrappedValue: viewModel)
        self.cluster = cluster
        self.onClose = onClose
        
        // 初始化本地状态
        _editedServer = State(initialValue: cluster.cluster.server)
        _editedCaData = State(initialValue: cluster.cluster.certificateAuthorityData ?? "")
        _editedSkipTls = State(initialValue: cluster.cluster.insecureSkipTlsVerify ?? false)
    }

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("kubernetes.cluster.details.title".localized(cluster.name))
                    .font(.title2.bold())
                Spacer()
                Button("button.done".localized, action: onClose) // 关闭按钮
            }
            Divider().padding(.bottom)

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("kubernetes.cluster.name.label".localized).bold().frame(width: 100, alignment: .trailing)
                        Text(cluster.name)
                    }
                    
                    VStack(alignment: .leading) {
                        Text("kubernetes.cluster.server.label".localized).bold()
                        TextField("https://<服务器地址>:<端口>", text: $editedServer)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .onChange(of: editedServer) { newValue in
                                // 更新视图模型中的数据
                                if let index = viewModel.kubeClusters.firstIndex(where: { $0.id == cluster.id }) {
                                    viewModel.kubeClusters[index].cluster.server = newValue
                                    viewModel.kubeConfig?.clusters = viewModel.kubeClusters
                                    viewModel.saveKubeConfig()
                                }
                            }
                    }
                    
                    VStack(alignment: .leading) {
                        Text("kubernetes.cluster.ca.label".localized).bold()
                        TextEditor(text: $editedCaData)
                            .font(.system(.body, design: .monospaced))
                            .frame(height: 120)
                            .border(Color.gray.opacity(0.5), width: 1)
                            .disableAutocorrection(true)
                            .onChange(of: editedCaData) { newValue in
                                // 更新视图模型中的数据
                                if let index = viewModel.kubeClusters.firstIndex(where: { $0.id == cluster.id }) {
                                    viewModel.kubeClusters[index].cluster.certificateAuthorityData = newValue.isEmpty ? nil : newValue
                                    viewModel.kubeConfig?.clusters = viewModel.kubeClusters
                                    viewModel.saveKubeConfig()
                                }
                            }
                    }
                    
                    Toggle("kubernetes.cluster.skip.tls.verification".localized, isOn: $editedSkipTls)
                        .onChange(of: editedSkipTls) { newValue in
                            // 更新视图模型中的数据
                            if let index = viewModel.kubeClusters.firstIndex(where: { $0.id == cluster.id }) {
                                viewModel.kubeClusters[index].cluster.insecureSkipTlsVerify = newValue
                                viewModel.kubeConfig?.clusters = viewModel.kubeClusters
                                viewModel.saveKubeConfig()
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
        let previewCluster = KubeCluster(
            name: "preview-cluster",
            cluster: ClusterDetails(
                server: "https://preview.server.com",
                certificateAuthorityData: "LS0tLS1...",
                insecureSkipTlsVerify: false
            )
        )

        var body: some View {
            ClusterDetailView(
                viewModel: previewViewModel,
                cluster: previewCluster,
                onClose: { print("Close panel") }
            )
        }
    }
    return PreviewWrapper()
        .frame(width: 400, height: 600)
} 