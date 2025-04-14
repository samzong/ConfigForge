//
//  ClusterDetailView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct ClusterDetailView: View {
    // 集群对象
    let cluster: KubeCluster
    
    // 编辑状态
    @State private var editedServer: String
    @State private var editedCertificateAuthority: String
    @State private var editedSkipTls: Bool
    
    // 关闭回调
    let onClose: () -> Void
    
    init(cluster: KubeCluster, onClose: @escaping () -> Void) {
        self.cluster = cluster
        self.onClose = onClose
        
        _editedServer = State(initialValue: cluster.cluster.server)
        _editedCertificateAuthority = State(initialValue: cluster.cluster.certificateAuthorityData ?? "")
        _editedSkipTls = State(initialValue: cluster.cluster.insecureSkipTlsVerify ?? false)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Text(L10n.Kubernetes.Cluster.Details.title(cluster.name))
                    .font(.title2)
                Spacer()
                Button(L10n.Button.done, action: onClose) // 关闭按钮
            }
            .padding(.bottom, 8)
            
            // 集群名称
            HStack {
                Text(L10n.Kubernetes.Cluster.Name.label).bold().frame(width: 100, alignment: .trailing)
                Text(cluster.name)
                    .foregroundColor(.primary)
            }
            
            // 服务器地址
            HStack(alignment: .top) {
                Text(L10n.Kubernetes.Cluster.Server.label).bold()
                     .frame(width: 100, alignment: .trailing) 
                VStack(alignment: .leading) {
                    TextField("", text: $editedServer)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .disabled(true) // 只读模式
                        .frame(width: 350)
                }
            }
            
            // 证书数据
            VStack(alignment: .leading) {
                HStack {
                    Text(L10n.Kubernetes.Cluster.Ca.label).bold()
                          .frame(width: 100, alignment: .trailing)
                    Spacer()
                }
                
                TextEditor(text: $editedCertificateAuthority)
                    .font(.system(.body, design: .monospaced))
                    .frame(height: 150)
                    .padding(4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    )
                    .disabled(true) // 只读模式
            }
            
            // TLS设置
            Toggle(L10n.Kubernetes.Cluster.Skip.Tls.verification, isOn: $editedSkipTls)
                .disabled(true) // 只读模式
                .padding(.top, 8)
                
            Spacer()
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

#Preview {
    struct PreviewWrapper: View {
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
                cluster: previewCluster,
                onClose: { print("Close panel") }
            )
        }
    }
    return PreviewWrapper()
        .frame(width: 400, height: 600)
} 