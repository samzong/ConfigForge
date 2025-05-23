//
//  EditorAreaView.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct EditorAreaView: View {
    @ObservedObject var viewModel: MainViewModel
    
    var body: some View {
        ZStack {
            if let selectedEntry = viewModel.selectedEntry {
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