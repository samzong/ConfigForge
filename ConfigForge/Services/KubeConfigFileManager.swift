import Foundation

// MARK: - KubeConfigFileManagerError Enum

enum KubeConfigFileManagerError: Error, LocalizedError {
    case configFileNotFound
    case cannotGetHomeDirectory
    case fileReadError(Error)
    case fileWriteError(Error)
    case directoryCreationError(Error)
    case parsingError(KubeConfigParserError)
    case encodingError(KubeConfigParserError)

    var errorDescription: String? {
        switch self {
        case .configFileNotFound:
            return "Kubeconfig 文件 (~/.kube/config) 未找到。" // This might be handled by returning default config instead
        case .cannotGetHomeDirectory:
            return "无法获取用户主目录路径。"
        case .fileReadError(let underlyingError):
            return "读取 Kubeconfig 文件失败: \(underlyingError.localizedDescription)"
        case .fileWriteError(let underlyingError):
            return "写入 Kubeconfig 文件失败: \(underlyingError.localizedDescription)"
        case .directoryCreationError(let underlyingError):
            return "创建 .kube 目录失败: \(underlyingError.localizedDescription)"
        case .parsingError(let parserError):
            return "Kubeconfig 解析错误: \(parserError.localizedDescription)"
        case .encodingError(let parserError):
            return "Kubeconfig 编码错误: \(parserError.localizedDescription)"
        }
    }
}

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
    /// - Throws: `KubeConfigFileManagerError.cannotGetHomeDirectory` if the home directory cannot be determined.
    /// - Returns: The URL path to the Kubeconfig file.
    func getConfigFilePath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName).appendingPathComponent(configFileName)
    }

    /// Returns the full path to the .kube directory (~/.kube).
        /// - Throws: `KubeConfigFileManagerError.cannotGetHomeDirectory` if the home directory cannot be determined.
        /// - Returns: The URL path to the .kube directory.
    func getConfigDirectoryPath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName)
    }

    /// Ensures the ~/.kube directory exists. Creates it if necessary.
    /// - Throws: `KubeConfigFileManagerError.directoryCreationError` if creation fails.
    private func ensureConfigDirectoryExists() throws {
        let directoryURL = try getConfigDirectoryPath()
        if !fileManager.fileExists(atPath: directoryURL.path) {
            do {
                try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
            } catch {
                throw KubeConfigFileManagerError.directoryCreationError(error)
            }
        }
    }


    /// Loads the KubeConfig object from the default path (~/.kube/config).
    /// If the file doesn't exist, it returns a default empty KubeConfig object.
    /// - Returns: A `Result` containing the loaded or default `KubeConfig`, or a `KubeConfigFileManagerError`.
    func loadConfig() -> Result<KubeConfig, KubeConfigFileManagerError> {
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
                return .failure(.parsingError(error))
            }

        } catch let error as KubeConfigFileManagerError {
            return .failure(error) // Propagate specific FileManager errors
        } catch {
            return .failure(.fileReadError(error)) // Catch general read errors
        }
    }

    /// Saves the KubeConfig object to the default path (~/.kube/config).
    /// Ensures the ~/.kube directory exists before writing.
    /// - Parameter config: The `KubeConfig` object to save.
    /// - Returns: A `Result` indicating success (`Void`) or a `KubeConfigFileManagerError`.
    func saveConfig(config: KubeConfig) -> Result<Void, KubeConfigFileManagerError> {
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
                return .failure(.encodingError(error))
            }

            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
            return .success(())

        } catch let error as KubeConfigFileManagerError {
             return .failure(error) // Propagate specific FileManager errors
        } catch {
            return .failure(.fileWriteError(error)) // Catch general write errors
        }
    }

    /// Backs up the provided Kubeconfig to the specified URL.
    /// - Parameters:
    ///   - config: The KubeConfig object to backup
    ///   - destination: The destination URL where the backup will be saved
    /// - Returns: A `Result` indicating success (`Void`) or a `KubeConfigFileManagerError`.
    func backupConfig(config: KubeConfig, to destination: URL) async throws {
        // Use the parser to encode
        let encodeResult = parser.encode(config: config)
        let yamlString: String
        
        switch encodeResult {
        case .success(let encodedString):
            yamlString = encodedString
        case .failure(let error):
            throw KubeConfigFileManagerError.encodingError(error)
        }
        
        // Write to the destination
        try yamlString.write(to: destination, atomically: true, encoding: .utf8)
    }

    /// Restores the Kubeconfig from the specified URL.
    /// - Parameter source: The source URL of the backup file
    /// - Returns: The restored KubeConfig object
    func restoreConfig(from source: URL) async throws -> KubeConfig {
        // Read the content from the source URL
        let yamlString = try String(contentsOf: source, encoding: .utf8)
        
        // Parse the content
        let parseResult = parser.decode(from: yamlString)
        switch parseResult {
        case .success(let config):
            // Also write back to the default location
            let configPath = try getConfigFilePath()
            try yamlString.write(to: configPath, atomically: true, encoding: .utf8)
            return config
        case .failure(let error):
            throw KubeConfigFileManagerError.parsingError(error)
        }
    }

    }
