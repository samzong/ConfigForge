import Foundation

class CLISSHConfigFileManager {
    private let fileManager = FileManager.default
    private let parser = CLISSHConfigParser()
    
    private var sshConfigPath: String {
        return NSHomeDirectory() + "/.ssh/config"
    }
    
    func getAllHosts() throws -> [SSHConfigEntry] {
        let content = try readConfigFile()
        return try parser.parseConfig(content: content)
    }
    
    func readConfigFile() throws -> String {
        if !fileManager.fileExists(atPath: sshConfigPath) {
            throw NSError(domain: "CLISSHConfigFileManager", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "SSH config file does not exist at \(sshConfigPath)"])
        }
        
        return try String(contentsOfFile: sshConfigPath, encoding: .utf8)
    }
}

class CLISSHConfigParser {
    func parseConfig(content: String) throws -> [SSHConfigEntry] {
        var entries: [SSHConfigEntry] = []
        var currentHost: String?
        var currentDirectives: [(key: String, value: String)] = []
        var inMultilineValue = false
        var multilineKey: String?
        
        let lines = content.components(separatedBy: .newlines)
        
        for lineIndex in 0..<lines.count {
            let line = lines[lineIndex]
            
            // Handle multiline values (lines starting with whitespace)
            if line.first?.isWhitespace == true && inMultilineValue && multilineKey != nil {
                if var lastDirective = currentDirectives.popLast(), lastDirective.key == multilineKey {
                    var lineContent = line.trimmingCharacters(in: .whitespaces)
                    if lineContent.hasSuffix("\\") {
                        lineContent = String(lineContent.dropLast())
                        lastDirective.value += " " + lineContent
                        currentDirectives.append(lastDirective)
                    } else {
                        lastDirective.value += " " + lineContent
                        currentDirectives.append(lastDirective)
                        inMultilineValue = false
                        multilineKey = nil
                    }
                }
                continue
            }
            
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Split the line into key and value
            let components = trimmedLine.components(separatedBy: .whitespaces)
            guard components.count >= 2 else { continue }
            
            let key = components[0]
            let value = components[1...].joined(separator: " ")
            let keyword = key.lowercased()
            
            // New Host entry starts
            if keyword == "host" {
                // Save the previous entry if exists
                if let host = currentHost, !host.isEmpty {
                    entries.append(SSHConfigEntry(host: host, directives: currentDirectives))
                }
                
                // Start a new entry
                currentHost = value
                currentDirectives = []
            } else if currentHost != nil {
                // Format the key properly
                let formattedKey = formatPropertyKey(keyword)
                
                // Handle multiline values
                if value.hasSuffix("\\") {
                    inMultilineValue = true
                    multilineKey = formattedKey
                    currentDirectives.append((key: formattedKey, value: String(value.dropLast())))
                } else {
                    currentDirectives.append((key: formattedKey, value: value))
                }
            }
        }
        
        // Add the last entry
        if let host = currentHost, !host.isEmpty {
            entries.append(SSHConfigEntry(host: host, directives: currentDirectives))
        }
        
        return entries
    }
    
    private func formatPropertyKey(_ key: String) -> String {
        let propertyMappings: [String: String] = [
            "hostname": "HostName",
            "user": "User",
            "port": "Port",
            "identityfile": "IdentityFile",
            "forwardagent": "ForwardAgent",
            "proxycommand": "ProxyCommand",
            "serveraliveinterval": "ServerAliveInterval",
            "serveralivecountmax": "ServerAliveCountMax",
            "stricthostkeychecking": "StrictHostKeyChecking",
            "userknownhostsfile": "UserKnownHostsFile",
            "connecttimeout": "ConnectTimeout"
        ]
        
        return propertyMappings[key] ?? key.capitalized
    }
} 