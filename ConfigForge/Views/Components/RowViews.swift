//
//  RowViews.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

struct HostRowView: View {
    let entry: SSHConfigEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.host)
                .font(.footnote)
                .foregroundColor(.primary)

            if !entry.hostname.isEmpty {
                Text(entry.hostname)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
