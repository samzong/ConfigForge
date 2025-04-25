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