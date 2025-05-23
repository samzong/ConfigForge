import Foundation

struct SSHConfigEntry {
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
    
    // Computed properties for backward compatibility and easy access
    var hostname: String? {
        directives.first { $0.key.lowercased() == "hostname" }?.value
    }
    
    var user: String? {
        directives.first { $0.key.lowercased() == "user" }?.value
    }
    
    var port: String? {
        directives.first { $0.key.lowercased() == "port" }?.value
    }
    
    var identityFile: String? {
        directives.first { $0.key.lowercased() == "identityfile" }?.value
    }
    
    var forwardAgent: String? {
        directives.first { $0.key.lowercased() == "forwardagent" }?.value
    }
    
    var proxyCommand: String? {
        directives.first { $0.key.lowercased() == "proxycommand" }?.value
    }
    
    var serverAliveInterval: String? {
        directives.first { $0.key.lowercased() == "serveraliveinterval" }?.value
    }
    
    var serverAliveCountMax: String? {
        directives.first { $0.key.lowercased() == "serveralivecountmax" }?.value
    }
    
    var strictHostKeyChecking: String? {
        directives.first { $0.key.lowercased() == "stricthostkeychecking" }?.value
    }
    
    var userKnownHostsFile: String? {
        directives.first { $0.key.lowercased() == "userknownhostsfile" }?.value
    }
    
    var connectTimeout: String? {
        directives.first { $0.key.lowercased() == "connecttimeout" }?.value
    }
    
    // Get other options that are not in the standard properties
    var otherOptions: [String: String] {
        let standardKeys = Set([
            "hostname", "user", "port", "identityfile", "forwardagent", 
            "proxycommand", "serveraliveinterval", "serveralivecountmax",
            "stricthostkeychecking", "userknownhostsfile", "connecttimeout"
        ])
        
        var others: [String: String] = [:]
        for directive in directives {
            if !standardKeys.contains(directive.key.lowercased()) {
                others[directive.key] = directive.value
            }
        }
        return others
    }
} 