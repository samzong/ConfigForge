//
//  ConfigListView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25. 
//

import SwiftUI

struct ConfigListView: View {
    @ObservedObject var viewModel: MainViewModel
    @State private var selectedConfigFileId: String?
    
    var body: some View {
        ConfigListContent(
            viewModel: viewModel,
            selectedConfigFileId: $selectedConfigFileId
        )
    }
}

private struct ConfigListContent: View {
    @ObservedObject var viewModel: MainViewModel
    @Binding var selectedConfigFileId: String?
    
    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isLoadingConfigFiles {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if viewModel.displayedConfigFiles.isEmpty {
                EmptyConfigView(viewModel: viewModel)
            } else {
                configFilesList
            }
        }
    }
    
    private var configFilesList: some View {
        List(viewModel.displayedConfigFiles, id: \.id, selection: $selectedConfigFileId) { configFile in
            ConfigFileRow(
                configFile: configFile, 
                isSelected: viewModel.selectedConfigFile?.id == configFile.id,
                isActive: configFile.isActive
            )
            .tag(configFile.id)
            .contextMenu {
                configFileContextMenu(for: configFile)
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.windowBackgroundColor))
        .onChange(of: selectedConfigFileId, perform: handleSelectionChange)
    }
    
    private func configFileContextMenu(for configFile: KubeConfigFile) -> some View {
        Group {
            Button(action: {
                viewModel.activateConfigFile(configFile)
            }) {
                Label(L10n.Kubernetes.Config.setActive, systemImage: "checkmark.circle")
            }
            .disabled(configFile.isActive || configFile.status != .valid)
            
            Divider()
            
            Button(role: .destructive, action: {
                viewModel.promptForDeleteConfigFile(configFile)
            }) {
                Label(L10n.App.delete, systemImage: "trash")
            }
        }
    }
    
    private func handleSelectionChange(newId: String?) {
        if let id = newId {
            if let configFile = viewModel.displayedConfigFiles.first(where: { $0.id == id }) {
                viewModel.selectConfigFile(configFile)
            }
        }
    }
}

struct ConfigFileRow: View {
    let configFile: KubeConfigFile
    let isSelected: Bool
    let isActive: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(configFile.displayName)
                .font(.footnote)
                .foregroundColor(.primary)
            HStack(spacing: 4) {
                if configFile.isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption2)
                } else if case .invalid = configFile.status {
                    Image(systemName: "exclamationmark.triangle.fill")  
                        .foregroundColor(.red)
                        .font(.caption2)
                }
                
                Text(statusText)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
    
    private var statusText: String {
        if configFile.isActive {
            return L10n.Kubernetes.Config.active
        } else {
            let dirPath = configFile.filePath.deletingLastPathComponent().path
            return dirPath
        }
    }
}

struct EmptyConfigView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 8)
            
            Text(L10n.Kubernetes.noSelection)
                .font(.title3)
                .foregroundColor(.primary)
            
            Text(L10n.Kubernetes.selectOrCreate)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
            
            Button(L10n.Kubernetes.createNew) {
                viewModel.createNewConfigFile()
            }
            .buttonStyle(BorderedButtonStyle())
            .controlSize(.large)
            .padding(.top)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
}

struct ConfigListView_Previews: PreviewProvider {
    static var previews: some View {
        ConfigListView(viewModel: MainViewModel())
            .frame(width: 300, height: 500)
    }
} 