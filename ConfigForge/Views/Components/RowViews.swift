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

// Kubernetes Context Row View
struct KubeContextRowView: View {
    let context: KubeContext
    let isCurrent: Bool
    
    var body: some View {
        VStack(alignment: .leading) {
            Text(context.name)
                .font(.headline)
                .fontWeight(isCurrent ? .bold : .regular)
                .foregroundColor(isCurrent ? .accentColor : .primary)
            
            Text(L10n.Kubernetes.Context.Cluster.User.format(context.context.cluster, context.context.user))
                .font(.caption)
                .foregroundColor(.secondary)
            if let namespace = context.context.namespace {
                Text(L10n.Kubernetes.Context.Namespace.format(namespace))
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
        }
        .padding(.vertical, 2)
    }
}

// Kubernetes Cluster Row View
struct KubeClusterRowView: View {
    let cluster: KubeCluster
    var body: some View {
        VStack(alignment: .leading) {
            Text(cluster.name).font(.headline)
            Text(cluster.cluster.server).font(.caption).foregroundColor(.secondary)
        }
         .padding(.vertical, 2)
    }
}

// Kubernetes User Row View
struct KubeUserRowView: View {
    let user: KubeUser
    var body: some View {
        VStack(alignment: .leading) {
             Text(user.name).font(.headline)
             // Display some indication of auth method if possible
             if user.user.token != nil {
                 Text(L10n.Kubernetes.User.Auth.token).font(.caption).foregroundColor(.secondary)
             } else if user.user.clientCertificateData != nil {
                 Text(L10n.Kubernetes.User.Auth.cert).font(.caption).foregroundColor(.secondary)
             } else {
                 Text(L10n.Kubernetes.User.Auth.other).font(.caption).foregroundColor(.secondary)
             }
        }
         .padding(.vertical, 2)
    }
} 