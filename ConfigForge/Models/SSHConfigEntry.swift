//
//  SSHConfigEntry.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

struct SSHConfigEntry: Identifiable {
    let id = UUID()
    var host: String
    var properties: [String: String]
    
    // 计算属性用于直接访问常用配置
    var hostname: String? { properties["HostName"] }
    var user: String? { properties["User"] }
    var port: String? { properties["Port"] }
    var identityFile: String? { properties["IdentityFile"] }
}
