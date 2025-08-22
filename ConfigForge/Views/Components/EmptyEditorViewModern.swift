//
//  EmptyEditorViewModern.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI

struct EmptyEditorViewModern: View {
    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "square.on.square.dashed")
                .font(.system(size: 56))
                .foregroundColor(.secondary)
                .symbolRenderingMode(.hierarchical)
                .padding(.bottom, 8)

            LocalizedText("editor.empty.title")
                .font(.title3)
                .foregroundColor(.primary)

            LocalizedText("editor.empty.description")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 300)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.windowBackgroundColor))
    }
} 