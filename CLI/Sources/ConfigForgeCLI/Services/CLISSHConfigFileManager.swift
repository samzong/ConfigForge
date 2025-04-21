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
        var currentEntry: SSHConfigEntry?
        
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            // Skip comments and empty lines
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // Split the line into key and value
            let components = trimmedLine.components(separatedBy: .whitespaces)
            guard components.count >= 2 else { continue }
            
            let key = components[0].lowercased()
            let value = components[1...].joined(separator: " ")
            
            // New Host entry starts
            if key == "host" {
                // Save the previous entry if exists
                if let entry = currentEntry {
                    entries.append(entry)
                }
                
                // Start a new entry
                currentEntry = SSHConfigEntry(host: value)
            } else if var entry = currentEntry {
                // Add the option to the current entry
                switch key {
                case "hostname":
                    entry.hostname = value
                case "user":
                    entry.user = value
                case "port":
                    entry.port = value
                case "identityfile":
                    entry.identityFile = value
                case "forwardagent":
                    entry.forwardAgent = value
                case "proxycommand":
                    entry.proxyCommand = value
                case "serveraliveinterval":
                    entry.serverAliveInterval = value
                case "serveralivecountmax":
                    entry.serverAliveCountMax = value
                case "stricthostkeychecking":
                    entry.strictHostKeyChecking = value
                case "userknownhostsfile":
                    entry.userKnownHostsFile = value
                case "connecttimeout":
                    entry.connectTimeout = value
                default:
                    entry.otherOptions[key] = value
                }
                
                currentEntry = entry
            }
        }
        
        // Add the last entry
        if let entry = currentEntry {
            entries.append(entry)
        }
        
        return entries
    }
} 