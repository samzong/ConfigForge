//
//  SSHConfigEntry.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

struct SSHConfigEntry: Identifiable, Hashable {
    let id = UUID()
    var host: String
    var properties: [String: String]
    
    // 计算属性用于直接访问常用配置
    var hostname: String? { 
        properties["HostName"] ?? ""
    }
    
    var user: String? { 
        properties["User"] ?? ""
    }
    
    var port: String? { 
        properties["Port"] ?? "22"
    }
    
    var identityFile: String? { 
        properties["IdentityFile"] ?? ""
    }
    
    // 实现Hashable协议
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SSHConfigEntry, rhs: SSHConfigEntry) -> Bool {
        lhs.id == rhs.id
    }
}
