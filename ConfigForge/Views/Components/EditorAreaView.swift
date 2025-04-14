//
//  EditorAreaView.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI

struct EditorAreaView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            if let selectedEntry = viewModel.selectedEntry {
                // --- Dynamically display the correct editor based on type --- 
                if let sshEntry = selectedEntry as? SSHConfigEntry {
                    ModernEntryEditorView(viewModel: viewModel, entry: sshEntry)
                        .id(sshEntry.id) 
                } else if let kubeContext = selectedEntry as? KubeContext {
                     // 实现KubeContextEditorView
                     if let contextIndex = viewModel.kubeContexts.firstIndex(where: { $0.id == kubeContext.id }) {
                         KubeContextEditorView(viewModel: viewModel, context: $viewModel.kubeContexts[contextIndex])
                             .id(kubeContext.id)
                     } else {
                         Text(L10n.Error.Binding.context).foregroundColor(.red)
                     }
                } else if let kubeCluster = selectedEntry as? KubeCluster {
                     // 将KubeClusterEditorView移到主区域显示
                     if let clusterIndex = viewModel.kubeClusters.firstIndex(where: { $0.id == kubeCluster.id }) {
                         KubeClusterEditorView(viewModel: viewModel, cluster: $viewModel.kubeClusters[clusterIndex])
                            .id(kubeCluster.id)
                     } else {
                         Text(L10n.Error.Binding.cluster).foregroundColor(.red)
                     }
                } else if let kubeUser = selectedEntry as? KubeUser {
                    // 实现KubeUserEditorView
                    if let userIndex = viewModel.kubeUsers.firstIndex(where: { $0.id == kubeUser.id }) {
                        KubeUserEditorView(viewModel: viewModel, user: $viewModel.kubeUsers[userIndex])
                            .id(kubeUser.id)
                    } else {
                        Text(L10n.Error.Binding.user).foregroundColor(.red)
                    }
                } else {
                    Text(L10n.Error.Editor.unknown)
                        .foregroundColor(.secondary)
                }
            } else {
                EmptyEditorViewModern()
            }
        }
        .frame(maxWidth: .infinity)
    }
} 