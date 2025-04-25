//
//  RowViews.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI

// 主机行视图
struct HostRowView: View {
    let entry: SSHConfigEntry
    
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.host)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
            
            if !entry.hostname.isEmpty {
                Text(entry.hostname)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
