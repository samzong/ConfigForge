import ArgumentParser
import Foundation
import CommonCrypto

struct KubeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kube",
        abstract: "Manage Kubernetes configurations",
        discussion: "Commands for managing Kubernetes contexts and configurations",
        subcommands: [
            KubeCurrentCommand.self,
            KubeListCommand.self,
            KubeSetCommand.self,
        ],
        aliases: ["k"]
    )
    
    func run() throws {
        print(KubeCommand.helpMessage())
    }
}

// List Kubernetes configurations
struct KubeListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all Kubernetes configurations",
        aliases: ["ls", "l"]
    )
    
    @Flag(name: .shortAndLong, help: "Validate configuration files")
    var validate = false
    
    func run() throws {
        let manager = KubeConfigManager()
        try manager.listConfigurations(validate: validate)
    }
}

// Set active Kubernetes configuration
struct KubeSetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set the active Kubernetes configuration",
        discussion: "Set the specified file as the active Kubernetes configuration"
    )
    
    @Argument(help: "The configuration file name to set as active")
    var filename: String
    
    func run() throws {
        let manager = KubeConfigManager()
        try manager.setConfiguration(filename: filename)
    }
}

// Show current Kubernetes configuration
struct KubeCurrentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "current",
        abstract: "Show current active Kubernetes configuration",
        aliases: ["cur"]
    )
    
    func run() throws {
        let manager = KubeConfigManager()
        try manager.showCurrentConfiguration()
    }
}

// Kubernetes Configuration Manager
class KubeConfigManager {
    private let fileManager = FileManager.default
    
    // Get paths
    private var homeDir: String {
        return NSHomeDirectory()
    }
    
    private var kubeConfigDir: String {
        return homeDir + "/.kube"
    }
    
    private var kubeConfigsDir: String {
        return kubeConfigDir + "/configs"
    }
    
    private var activeConfigPath: String {
        return kubeConfigDir + "/config"
    }
    
    // Calculate MD5 hash for a file
    private func calculateMD5(filePath: String) throws -> String {
        // 使用Data直接读取文件内容，避免文件句柄可能的缓存问题
        let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
        
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { unsafeBytes in
            _ = CC_MD5(unsafeBytes.baseAddress, CC_LONG(data.count), &digest)
        }
        
        return digest.map { String(format: "%02x", $0) }.joined()
    }
    
    // Check if Kubernetes config is valid
    private func isValidKubeConfig(filePath: String) -> Bool {
        do {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            let yamlString = String(data: data, encoding: .utf8) ?? ""
            
            // Basic validation - check if required fields exist
            return yamlString.contains("apiVersion") &&
                   yamlString.contains("clusters") &&
                   yamlString.contains("contexts") &&
                   yamlString.contains("users")
        } catch {
            return false
        }
    }
    
    // Get current context from config file
    private func getCurrentContext() throws -> String {
        let data = try Data(contentsOf: URL(fileURLWithPath: activeConfigPath))
        guard let yamlString = String(data: data, encoding: .utf8) else {
            throw NSError(domain: "KubeConfigManager", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not parse config file"])
        }
        
        // Very basic parsing to extract current-context
        let lines = yamlString.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.hasPrefix("current-context:") {
                let parts = trimmedLine.components(separatedBy: ":")
                if parts.count > 1 {
                    return parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        return "unknown"
    }
    
    // Ensure configs directory exists
    private func ensureConfigsDirExists() throws {
        if !fileManager.fileExists(atPath: kubeConfigsDir) {
            try fileManager.createDirectory(atPath: kubeConfigsDir, withIntermediateDirectories: true)
            print("Created Kubernetes configs directory at \(kubeConfigsDir)")
        }
    }
    
    // Generate timestamp for filenames
    private func getTimestamp() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd-HHmmss"
        return dateFormatter.string(from: Date())
    }
    
    // List all Kubernetes configurations
    func listConfigurations(validate: Bool) throws {
        // Create configs directory if it doesn't exist
        try ensureConfigsDirExists()
        
        // 确保活动配置文件存在
        guard fileManager.fileExists(atPath: activeConfigPath) else {
            print("No active Kubernetes configuration found.")
            if let configs = try? fileManager.contentsOfDirectory(atPath: kubeConfigsDir), !configs.isEmpty {
                print("Available configurations (none active):")
                for config in configs {
                    print("  \(config)")
                }
            } else {
                print("No configurations found in \(kubeConfigsDir)")
            }
            return
        }
        
        // 计算活动配置的哈希值前，确保访问的是最新文件
        try? fileManager.attributesOfItem(atPath: activeConfigPath)
        
        // Get active config hash
        let activeConfigHash: String
        do {
            activeConfigHash = try calculateMD5(filePath: activeConfigPath)
        } catch {
            print("Error: Could not read active configuration: \(error.localizedDescription)")
            return
        }
        
        // List configurations
        let contents = try fileManager.contentsOfDirectory(atPath: kubeConfigsDir)
        let configFiles = contents.filter { 
            $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") || $0.hasSuffix(".kubeconfig") 
        }.sorted()
        
        if configFiles.isEmpty {
            print("No Kubernetes configurations found in \(kubeConfigsDir)")
            return
        }
        
        print("Available Kubernetes configurations:")
        
        // First find exact hash match to determine active config
        var activeFound = false
        var exactActiveFilename: String? = nil
        
        // Debug output for troubleshooting
        //print("Active config hash: \(activeConfigHash)")
        
        // First pass - look for exact match
        for file in configFiles {
            let filePath = kubeConfigsDir + "/" + file
            
            // 确保访问的是最新文件
            try? fileManager.attributesOfItem(atPath: filePath)
            
            do {
                let fileHash = try calculateMD5(filePath: filePath)
                //print("File \(file) hash: \(fileHash)")
                if fileHash == activeConfigHash {
                    exactActiveFilename = file
                    activeFound = true
                    break
                }
            } catch {
                // Silently continue if we can't calculate hash
            }
        }
        
        // Second pass - display list
        for file in configFiles {
            let filePath = kubeConfigsDir + "/" + file
            
            // Check if this is the active config
            let isActive = file == exactActiveFilename
            
            // Check if config is valid when validation flag is set
            var isValid = true
            if validate {
                isValid = isValidKubeConfig(filePath: filePath)
            }
            
            // Format and print
            if isActive {
                if !isValid && validate {
                    print("* \(file) (active) [invalid]")
                } else {
                    print("* \(file) (active)")
                }
            } else {
                if !isValid && validate {
                    print("  \(file) [invalid]")
                } else {
                    print("  \(file)")
                }
            }
        }
        
        if !activeFound {
            print("\nNote: Active configuration not found in configs directory")
            print("Active config path: \(activeConfigPath)")
        }
    }
    
    // Set active Kubernetes configuration
    func setConfiguration(filename: String) throws {
        // Ensure configs directory exists
        try ensureConfigsDirExists()
        
        let sourcePath = kubeConfigsDir + "/" + filename
        
        // Check if the file exists
        if !fileManager.fileExists(atPath: sourcePath) {
            print("Error: Configuration file '\(filename)' not found in \(kubeConfigsDir)")
            return
        }
        
        // Validate the config
        if !isValidKubeConfig(filePath: sourcePath) {
            print("Warning: '\(filename)' may not be a valid Kubernetes configuration file")
            print("Do you want to continue? (y/N): ", terminator: "")
            if let response = readLine()?.lowercased(), response != "y" {
                print("Operation canceled")
                return
            }
        }
        
        // Create backup of current config if it exists
        if fileManager.fileExists(atPath: activeConfigPath) {
            let backupPath = activeConfigPath + ".bak"
            // Remove old backup if exists
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
            try fileManager.copyItem(atPath: activeConfigPath, toPath: backupPath)
        }
        
        // Copy the new config file to a temporary location
        let tempPath = activeConfigPath + ".tmp"
        // Remove temporary file if exists
        if fileManager.fileExists(atPath: tempPath) {
            try fileManager.removeItem(atPath: tempPath)
        }
        try fileManager.copyItem(atPath: sourcePath, toPath: tempPath)
        
        // Remove existing config file if exists
        if fileManager.fileExists(atPath: activeConfigPath) {
            try fileManager.removeItem(atPath: activeConfigPath)
        }
        
        // Move temporary file to active config path
        try fileManager.moveItem(atPath: tempPath, toPath: activeConfigPath)
        
        print("Successfully switched active Kubernetes configuration to '\(filename)'")
    }
    
    // Show current Kubernetes configuration
    func showCurrentConfiguration() throws {
        // Ensure the active config exists
        if !fileManager.fileExists(atPath: activeConfigPath) {
            print("No active Kubernetes configuration found")
            return
        }
        
        // Ensure configs directory exists
        try ensureConfigsDirExists()
        
        // Calculate hash of active config
        let activeConfigHash = try calculateMD5(filePath: activeConfigPath)
        
        // Try to find matching file
        let contents = try fileManager.contentsOfDirectory(atPath: kubeConfigsDir)
        let configFiles = contents.filter { 
            $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") || $0.hasSuffix(".kubeconfig") 
        }
        
        var activeFilename = "unknown"
        for file in configFiles {
            let filePath = kubeConfigsDir + "/" + file
            let fileHash = try calculateMD5(filePath: filePath)
            
            if fileHash == activeConfigHash {
                activeFilename = file
                break
            }
        }
        
        if activeFilename == "unknown" {
            print("Current configuration: Unknown (not in configs directory)")
        } else {
            print("Current configuration: \(activeFilename)")
        }
    }
} 