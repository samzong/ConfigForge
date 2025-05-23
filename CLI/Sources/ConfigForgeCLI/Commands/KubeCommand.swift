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
    
    @Argument(help: "The configuration number or filename to set as active")
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
    
    // Get sorted list of config files
    private func getSortedConfigFiles() throws -> [String] {
        let contents = try fileManager.contentsOfDirectory(atPath: kubeConfigsDir)
        return contents.filter { 
            $0.hasSuffix(".yaml") || $0.hasSuffix(".yml") || $0.hasSuffix(".kubeconfig") 
        }.sorted()
    }
    
    // List all Kubernetes configurations
    func listConfigurations(validate: Bool) throws {
        // Create configs directory if it doesn't exist
        try ensureConfigsDirExists()
        
        guard fileManager.fileExists(atPath: activeConfigPath) else {
            print("No active Kubernetes configuration found.")
            if let configs = try? getSortedConfigFiles(), !configs.isEmpty {
                print("Available configurations (none active):")
                for (index, config) in configs.enumerated() {
                    print("  \(index + 1). \(config)")
                }
                print("")
                print("Use 'cf k set <number>' or 'cf k set <filename>' to activate a configuration")
            } else {
                print("No configurations found in \(kubeConfigsDir)")
            }
            return
        }
        
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
        let configFiles = try getSortedConfigFiles()
        
        if configFiles.isEmpty {
            print("No Kubernetes configurations found in \(kubeConfigsDir)")
            return
        }
        
        print("Available Kubernetes configurations:")
        
        // First find exact hash match to determine active config
        var activeFound = false
        var exactActiveFilename: String? = nil
        
        // First pass - look for exact match
        for file in configFiles {
            let filePath = kubeConfigsDir + "/" + file
            
            // 确保访问的是最新文件
            try? fileManager.attributesOfItem(atPath: filePath)
            
            do {
                let fileHash = try calculateMD5(filePath: filePath)
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
        for (index, file) in configFiles.enumerated() {
            let filePath = kubeConfigsDir + "/" + file
            let number = index + 1
            
            // Check if this is the active config
            let isActive = file == exactActiveFilename
            
            // Check if config is valid when validation flag is set
            var isValid = true
            if validate {
                isValid = isValidKubeConfig(filePath: filePath)
            }
            
            // Format and print
            let activeMarker = isActive ? "* " : "  "
            let validationMarker = (!isValid && validate) ? " [invalid]" : ""
            let activeLabel = isActive ? " (active)" : ""
            
            print("\(activeMarker)\(number). \(file)\(activeLabel)\(validationMarker)")
        }
        
        print("")
        print("Use 'cf k set <number>' or 'cf k set <filename>' to switch configuration")
        print("Use 'cf k current' to show current active configuration")
        
        if !activeFound {
            print("\nNote: Active configuration not found in configs directory")
            print("Active config path: \(activeConfigPath)")
        }
    }
    
    // Set active Kubernetes configuration
    func setConfiguration(filename: String) throws {
        // Ensure configs directory exists
        try ensureConfigsDirExists()
        
        let configFiles = try getSortedConfigFiles()
        
        if configFiles.isEmpty {
            print("Error: No configurations found in \(kubeConfigsDir)")
            return
        }
        
        let targetFilename: String
        
        // Check if input is a number
        if let index = Int(filename), index > 0, index <= configFiles.count {
            targetFilename = configFiles[index - 1]
            print("Selected configuration \(index): \(targetFilename)")
        } else {
            // Use filename directly
            targetFilename = filename
        }
        
        let sourcePath = kubeConfigsDir + "/" + targetFilename
        
        // Check if the file exists
        if !fileManager.fileExists(atPath: sourcePath) {
            print("Error: Configuration file '\(targetFilename)' not found in \(kubeConfigsDir)")
            print("Use 'cf k l' to see available configurations")
            return
        }
        
        // Validate the config
        if !isValidKubeConfig(filePath: sourcePath) {
            print("Warning: '\(targetFilename)' may not be a valid Kubernetes configuration file")
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
        
        print("Successfully switched active Kubernetes configuration to '\(targetFilename)'")
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
        let configFiles = try getSortedConfigFiles()
        
        var activeFilename = "unknown"
        var activeIndex: Int? = nil
        
        for (index, file) in configFiles.enumerated() {
            let filePath = kubeConfigsDir + "/" + file
            let fileHash = try calculateMD5(filePath: filePath)
            
            if fileHash == activeConfigHash {
                activeFilename = file
                activeIndex = index + 1
                break
            }
        }
        
        if let index = activeIndex {
            print("Current configuration: \(index). \(activeFilename)")
        } else {
            print("Current configuration: Unknown (not in configs directory)")
        }
    }
} 