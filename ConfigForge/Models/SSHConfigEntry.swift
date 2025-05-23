//
//  SSHConfigEntry.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

struct SSHConfigEntry: Identifiable, Hashable, Sendable {
    let id: UUID
    var host: String
    var directives: [(key: String, value: String)] = []
    
    // Default initializer that generates a new UUID
    init(host: String, directives: [(key: String, value: String)] = []) {
        self.id = UUID()
        self.host = host
        self.directives = directives
    }
    
    // Initializer that accepts a specific UUID (for updates)
    init(id: UUID, host: String, directives: [(key: String, value: String)] = []) {
        self.id = id
        self.host = host
        self.directives = directives
    }
    
    var hostname: String {
        directives.first { $0.key.lowercased() == "hostname" }?.value ?? ""
    }
    
    var user: String {
        directives.first { $0.key.lowercased() == "user" }?.value ?? ""
    }
    
    var port: String {
        directives.first { $0.key.lowercased() == "port" }?.value ?? "22"
    }
    
    var identityFile: String {
        directives.first { $0.key.lowercased() == "identityfile" }?.value ?? ""
    }
    var isPortValid: Bool {
        guard let portStr = directives.first(where: { $0.key.lowercased() == "port" })?.value, !portStr.isEmpty else {
            return true
        }
        
        guard let port = Int(portStr) else {
            return false
        }
        
        return port >= 1 && port <= 65535
    }
    var isHostNameValid: Bool {
        guard let hostName = directives.first(where: { $0.key.lowercased() == "hostname" })?.value, !hostName.isEmpty else {
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
