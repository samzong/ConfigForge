//
//  MessageBanner.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI

struct MessageBanner: View {
    let message: AppMessage
    let onDismiss: () -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .font(.headline)
                .foregroundColor(bannerColor)
            
            Text(message.message)
                .font(.footnote)
                .foregroundColor(.primary)
            
            if message.type != .success {
                Button(action: {
                    onDismiss()
                }) {
                    Image(systemName: "xmark")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(PlainButtonStyle())
                .padding(.leading, 4)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 16)
        .background(.thickMaterial, in: Capsule())
        .overlay(Capsule().stroke(bannerColor, lineWidth: 2))
        .shadow(color: bannerColor.opacity(0.4), radius: 12, x: 0, y: 8)
        .padding(.top, 16)
    }
    
    private var iconName: String {
        switch message.type {
        case .success: return "checkmark.circle.fill"
        case .error: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    private var bannerColor: Color {
        switch message.type {
        case .success: return Color.green.opacity(0.9)
        case .error: return Color.red.opacity(0.9)
        case .info: return Color.blue.opacity(0.9)
        }
    }
} 