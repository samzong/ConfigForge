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
    var isPortValid: Bool {
        guard let portStr = properties["Port"], !portStr.isEmpty else {
            return true 
        }
        
        guard let port = Int(portStr) else {
            return false 
        }
        
        return port >= 1 && port <= 65535 
    }
    var isHostNameValid: Bool {
        guard let hostName = properties["HostName"], !hostName.isEmpty else {
            return true 
        }
        let trimmed = hostName.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: SSHConfigEntry, rhs: SSHConfigEntry) -> Bool {
        lhs.id == rhs.id
    }
}
