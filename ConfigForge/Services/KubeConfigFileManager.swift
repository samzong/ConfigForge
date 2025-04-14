import Foundation

// MARK: - KubeConfigFileManager Class

class KubeConfigFileManager {

    private let fileManager: FileManager
    private let parser: KubeConfigParser
    private let configDirectoryName = ".kube"
    private let configFileName = "config"

    init(fileManager: FileManager = .default, parser: KubeConfigParser = KubeConfigParser()) {
        self.fileManager = fileManager
        self.parser = parser
    }

    /// Returns the full path to the Kubeconfig file (~/.kube/config).
    /// - Throws: `ConfigForgeError.fileAccess` if the home directory cannot be determined.
    /// - Returns: The URL path to the Kubeconfig file.
    func getConfigFilePath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName).appendingPathComponent(configFileName)
    }

    /// Returns the full path to the .kube directory (~/.kube).
    /// - Throws: `ConfigForgeError.fileAccess` if the home directory cannot be determined.
    /// - Returns: The URL path to the .kube directory.
    func getConfigDirectoryPath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName)
    }

    /// Ensures the ~/.kube directory exists. Creates it if necessary.
    /// - Throws: `ConfigForgeError.fileAccess` if creation fails.
    private func ensureConfigDirectoryExists() throws {
        let directoryURL = try getConfigDirectoryPath()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw ConfigForgeError.fileAccess("创建 .kube 目录失败: \(error.localizedDescription)")
            }
        }
    }


    /// Loads the KubeConfig object from the default path (~/.kube/config).
    /// If the file doesn't exist, it returns a default empty KubeConfig object.
    /// - Returns: A `Result` containing the loaded or default `KubeConfig`, or a `ConfigForgeError`.
    func loadConfig() -> Result<KubeConfig, ConfigForgeError> {
        do {
            let configPath = try getConfigFilePath()

            guard fileManager.fileExists(atPath: configPath.path) else {
                // File doesn't exist, return a default empty config
                return .success(KubeConfig(apiVersion: nil, kind: nil, preferences: nil, clusters: [], contexts: [], users: [], currentContext: nil))
            }

            let yamlString = try String(contentsOf: configPath, encoding: .utf8)
            
            // Use the parser to decode
            let parseResult = parser.decode(from: yamlString)
            switch parseResult {
            case .success(let config):
                return .success(config)
            case .failure(let error):
                return .failure(error)
            }

        } catch let error as ConfigForgeError {
            return .failure(error) // Propagate specific errors
        } catch {
            return .failure(.configRead("读取 Kubeconfig 文件失败: \(error.localizedDescription)"))
        }
    }

    /// Saves the KubeConfig object to the default path (~/.kube/config).
    /// Ensures the ~/.kube directory exists before writing.
    /// - Parameter config: The `KubeConfig` object to save.
    /// - Returns: A `Result` indicating success (`Void`) or a `ConfigForgeError`.
    func saveConfig(config: KubeConfig) -> Result<Void, ConfigForgeError> {
        do {
            // Ensure the directory exists first
            try ensureConfigDirectoryExists()

            let configPath = try getConfigFilePath()

            // Use the parser to encode
            let encodeResult = parser.encode(config: config)
            let yamlString: String

            switch encodeResult {
            case .success(let encodedString):
                yamlString = encodedString
            case .failure(let error):
                return .failure(error)
            }

            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
            return .success(())

        } catch let error as ConfigForgeError {
             return .failure(error) // Propagate specific errors
        } catch {
            return .failure(.configWrite("写入 Kubeconfig 文件失败: \(error.localizedDescription)"))
        }
    }

    /// Backs up the provided Kubeconfig to the specified URL.
    /// - Parameters:
    ///   - config: The KubeConfig object to backup
    ///   - destination: The destination URL where the backup will be saved
    /// - Returns: A `Result` indicating success (`Void`) or a `ConfigForgeError`.
    func backupConfig(config: KubeConfig, to destination: URL) async throws {
        // Use the parser to encode
        let encodeResult = parser.encode(config: config)
        let yamlString: String
        
        switch encodeResult {
        case .success(let encodedString):
            yamlString = encodedString
        case .failure(let error):
            throw error
        }
        
        // Write to the destination
        do {
            try yamlString.write(to: destination, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigForgeError.configWrite("备份 Kubeconfig 文件失败: \(error.localizedDescription)")
        }
    }

    /// Restores the Kubeconfig from the specified URL.
    /// - Parameter source: The source URL of the backup file
    /// - Returns: The restored KubeConfig object
    func restoreConfig(from source: URL) async throws -> KubeConfig {
        // Read the content from the source URL
        let yamlString: String
        do {
            yamlString = try String(contentsOf: source, encoding: .utf8)
        } catch {
            throw ConfigForgeError.configRead("从备份恢复 Kubeconfig 文件失败: \(error.localizedDescription)")
        }
        
        // Parse the content
        let parseResult = parser.decode(from: yamlString)
        switch parseResult {
        case .success(let config):
            // Also write back to the default location
            let configPath = try getConfigFilePath()
            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
            return config
        case .failure(let error):
            throw error
        }
    }
}
