//
//  SSHConfigEntry.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

struct SSHConfigEntry: Identifiable, Hashable, Sendable {
    let id = UUID()
    var host: String
    var properties: [String: String]
    
    // 计算属性用于直接访问常用配置
    var hostname: String { 
        properties["HostName"] ?? ""
    }
    
    var user: String { 
        properties["User"] ?? ""
    }
    
    var port: String { 
        properties["Port"] ?? "22"
    }
    
    var identityFile: String { 
        properties["IdentityFile"] ?? ""
    }
    
    // 验证端口号是否有效
    var isPortValid: Bool {
        guard let portStr = properties["Port"], !portStr.isEmpty else {
            return true // 如果没有设置端口，使用默认值22是有效的
        }
        
        guard let port = Int(portStr) else {
            return false // 端口必须是数字
        }
        
        return port >= 1 && port <= 65535 // 有效端口范围
    }
    
    // 验证主机名是否有效
    var isHostNameValid: Bool {
        guard let hostName = properties["HostName"], !hostName.isEmpty else {
            return true // 空主机名在技术上是有效的，尽管不太有用
        }
        
        // 简单的主机名验证 - 不能仅包含空格
        let trimmed = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
    
    // 实现Hashable协议
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SSHConfigEntry, rhs: SSHConfigEntry) -> Bool {
        lhs.id == rhs.id
    }
}
