import Foundation

// MARK: - KubeConfigFileManager Class

class KubeConfigFileManager {

    private let fileManager: FileManager
    private let fileUtils: FileSystemUtils
    private let configDirectoryName = ".kube"
    private let configFileName = "config"
    private let configsDirectoryName = "configs"
    private let backupFileName = "config.bak"

    init(fileManager: FileManager = .default, 
         fileUtils: FileSystemUtils = FileSystemUtils.shared) {
        self.fileManager = fileManager
        self.fileUtils = fileUtils
        
        do {
            try ensureConfigDirectoryExists()
            try ensureConfigsDirectoryExists()
        } catch {
            print("初始化目录结构失败: \(error.localizedDescription)")
        }
    }

    /// Returns the full path to the Kubeconfig file (~/.kube/config).
    /// - Throws: `ConfigForgeError.fileAccess` if the home directory cannot be determined.
    /// - Returns: The URL path to the Kubeconfig file.
    func getConfigFilePath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName).appendingPathComponent(configFileName)
    }
    
    /// Returns the full path to the Kubeconfig backup file (~/.kube/config.bak).
    /// - Throws: `ConfigForgeError.fileAccess` if the home directory cannot be determined.
    /// - Returns: The URL path to the Kubeconfig backup file.
    func getConfigBackupFilePath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName).appendingPathComponent(backupFileName)
    }

    /// Returns the full path to the .kube directory (~/.kube).
    /// - Throws: `ConfigForgeError.fileAccess` if the home directory cannot be determined.
    /// - Returns: The URL path to the .kube directory.
    func getConfigDirectoryPath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName)
    }
    
    /// Returns the full path to the configs directory (~/.kube/configs).
    /// - Throws: `ConfigForgeError.fileAccess` if the home directory cannot be determined.
    /// - Returns: The URL path to the configs directory.
    func getConfigsDirectoryPath() throws -> URL {
        let configDirURL = try getConfigDirectoryPath()
        return configDirURL.appendingPathComponent(configsDirectoryName)
    }

    /// Ensures the ~/.kube directory exists. Creates it if necessary.
    /// - Throws: `ConfigForgeError.fileAccess` if creation fails.
    private func ensureConfigDirectoryExists() throws {
        let directoryURL = try getConfigDirectoryPath()
        let result = fileUtils.createDirectoryIfNeeded(at: directoryURL)
        
        if case .failure(let error) = result {
            throw error
        }
    }
    
    /// Ensures the ~/.kube/configs directory exists. Creates it if necessary.
    /// - Throws: `ConfigForgeError.fileAccess` if creation fails.
    func ensureConfigsDirectoryExists() throws {
        let directoryURL = try getConfigsDirectoryPath()
        let result = fileUtils.createDirectoryIfNeeded(at: directoryURL)
        
        if case .failure(let error) = result {
            throw error
        }
    }

    /// Loads the Kubeconfig content from the default path (~/.kube/config).
    /// If the file doesn't exist, it returns an empty string.
    /// - Returns: A `Result` containing the YAML string or a `ConfigForgeError`.
    func loadConfig() -> Result<String, ConfigForgeError> {
        do {
            let configPath = try getConfigFilePath()

            // Use FileSystemUtils to check if the file exists
            guard fileManager.fileExists(atPath: configPath.path) else {
                // File doesn't exist, return an empty string
                return .success("")
            }

            // Use FileSystemUtils to read the file
            let readResult = fileUtils.readFile(at: configPath)
            switch readResult {
            case .success(let yamlString):
                // Return the raw YAML string directly
                return .success(yamlString)
            case .failure(let error):
                return .failure(error) // Propagate file system errors
            }

        } catch let error as ConfigForgeError {
            return .failure(error) // Propagate specific errors
        } catch {
            return .failure(.configRead("读取 Kubeconfig 文件失败: \\(error.localizedDescription)"))
        }
    }

    /// Saves the Kubeconfig content (raw YAML string) to the default path (~/.kube/config).
    /// Ensures the ~/.kube directory exists before writing.
    /// - Parameter content: The YAML string content to save.
    /// - Returns: A `Result` indicating success (`Void`) or a `ConfigForgeError`.
    func saveConfig(content: String) -> Result<Void, ConfigForgeError> {
        do {
            // Ensure the directory exists first
            try ensureConfigDirectoryExists()

            let configPath = try getConfigFilePath()

            // Use FileSystemUtils to write the raw string content
            return fileUtils.writeFile(content: content, to: configPath, createBackup: true)

        } catch let error as ConfigForgeError {
             return .failure(error) // Propagate specific errors
        } catch {
            return .failure(.configWrite("写入 Kubeconfig 文件失败: \\(error.localizedDescription)"))
        }
    }

    /// Backs up the provided Kubeconfig content (raw YAML string) to the specified URL.
    /// - Parameters:
    ///   - content: The YAML string content to backup.
    ///   - destination: The destination URL where the backup will be saved.
    /// - Returns: A `Result` indicating success (`Void`) or a `ConfigForgeError`.
    func backupConfig(content: String, to destination: URL) async throws {
        // Use FileSystemUtils to write the raw string content
        let writeResult = fileUtils.writeFile(content: content, to: destination)
        
        if case .failure(let error) = writeResult {
            throw error
        }
    }

    /// Restores the Kubeconfig from the specified URL, returning the content as a string.
    /// Also writes the restored content back to the default config path.
    /// - Parameter source: The source URL of the backup file.
    /// - Returns: A `Result` containing the restored YAML string or a `ConfigForgeError`.
    func restoreConfig(from source: URL) async -> Result<String, ConfigForgeError> {
        // Use FileSystemUtils to read the file
        let readResult = fileUtils.readFile(at: source)
        
        switch readResult {
        case .success(let yamlString):
            do {
                // Also write back to the default location
                let configPath = try getConfigFilePath()
                let writeResult = fileUtils.writeFile(content: yamlString, to: configPath, createBackup: false) // Don't create backup when restoring

                if case .failure(let error) = writeResult {
                     return .failure(error) // Return failure if writing back fails
                }
                
                // Return the restored content
                return .success(yamlString)
                
            } catch let error as ConfigForgeError {
                return .failure(error) // Propagate specific errors from getConfigFilePath
            } catch {
                 return .failure(.configWrite("恢复过程中写回 Kubeconfig 文件失败: \\(error.localizedDescription)"))
            }
            
        case .failure(let error):
            // If reading the source fails, return the error
            return .failure(error)
        }
    }
    
    /// 创建默认的备份文件 (~/.kube/config.bak)
    /// - Returns: 成功或失败的结果
    func createDefaultBackup() async -> Result<Void, ConfigForgeError> {
        do {
            // 加载当前配置
            let loadResult = loadConfig()
            
            switch loadResult {
            case .success(let config):
                // 创建备份
                let backupPath = try getConfigBackupFilePath()
                try await backupConfig(content: config, to: backupPath)
                return .success(())
            case .failure(let error):
                return .failure(error)
            }
        } catch {
            if let configError = error as? ConfigForgeError {
                return .failure(configError)
            }
            return .failure(.configWrite("创建备份文件失败: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - 第二阶段开发: 配置文件管理
    
    /// 发现并扫描 ~/.kube/configs/ 目录中的所有配置文件
    /// - Returns: 配置文件列表或错误
    func discoverConfigFiles() async -> Result<[KubeConfigFile], ConfigForgeError> {
        do {
            // 确保目录存在
            try ensureConfigsDirectoryExists()
            
            // 获取目录URL
            let configsDir = try getConfigsDirectoryPath()
            
            // 获取主配置文件中的标识注释
            let mainConfigPath = try getConfigFilePath()
            var activeConfigIdentifier: String? = nil
            
            if fileManager.fileExists(atPath: mainConfigPath.path) {
                do {
                    let mainConfigContent = try String(contentsOf: mainConfigPath, encoding: .utf8)
                    // 查找特殊注释，格式为：# ConfigForge-ActiveConfig: filename.yaml
                    if let range = mainConfigContent.range(of: "# ConfigForge-ActiveConfig: .*", options: .regularExpression) {
                        let commentLine = String(mainConfigContent[range])
                        // 提取配置文件名
                        if let filenameRange = commentLine.range(of: "(?<=# ConfigForge-ActiveConfig: ).*", options: .regularExpression) {
                            activeConfigIdentifier = String(commentLine[filenameRange])
                        }
                    }
                } catch {
                    print("Warning: Could not read active config: \(error.localizedDescription)")
                }
            }
            
            // 配置文件数组
            var configFiles = [KubeConfigFile]()
            
            // 列出 configs 目录中的所有文件
            let directoryContents = try fileManager.contentsOfDirectory(at: configsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            
            // 筛选出 YAML 和 YML 文件
            let yamlFiles = directoryContents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return fileExtension == "yaml" || fileExtension == "yml"
            }
            
            // 为每个文件创建 KubeConfigFile 对象
            for fileURL in yamlFiles {
                // 判断是否为活动配置 - 基于文件名比较
                let isActive = activeConfigIdentifier != nil && 
                               fileURL.lastPathComponent == activeConfigIdentifier
                
                // 创建配置文件对象
                if var configFile = KubeConfigFile.from(url: fileURL, fileType: .stored) {
                    // 如果与活动配置标识符匹配，标记为活动状态
                    if isActive {
                        configFile.isActive = true
                    }
                    configFiles.append(configFile)
                }
            }
            
            return .success(configFiles)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.fileAccess("扫描配置文件目录失败: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - 增强备份功能
    
    /// 使用时间戳创建自定义备份文件
    /// - Parameters:
    ///   - content: 要备份的 YAML 字符串内容
    ///   - customName: 可选的自定义名称 (默认使用时间戳)
    /// - Returns: 备份操作的结果，成功时返回备份文件路径
    func createCustomBackup(content: String, customName: String? = nil) async -> Result<URL, ConfigForgeError> {
        do {
            // 确保目录存在
            try ensureConfigsDirectoryExists()
            
            // 生成文件名 (使用时间戳或自定义名称)
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: ".", with: "-") // Also replace periods
            
            let backupFileName: String
            if let customName = customName, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                 // Sanitize custom name slightly
                 let sanitizedName = customName.replacingOccurrences(of: "/", with: "-")
                                              .replacingOccurrences(of: "\\\\", with: "-")
                 backupFileName = "backup-\(sanitizedName).yaml"
            } else {
                 backupFileName = "backup-\(timestamp).yaml"
            }
            
            // 创建备份文件路径
            let configsDir = try getConfigsDirectoryPath()
            let backupPath = configsDir.appendingPathComponent(backupFileName)
            
            // 备份配置内容 (直接写入字符串)
            try await backupConfig(content: content, to: backupPath)
            
            return .success(backupPath)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("创建自定义备份失败: \\\\(error.localizedDescription)"))
        }
    }
    
    /// 恢复（激活）指定的配置文件内容到主配置文件 (~/.kube/config) 并创建备份
    /// - Parameter configFile: 要恢复（激活）的配置文件
    /// - Returns: 恢复操作的结果
    func restoreConfigFile(_ configFile: KubeConfigFile) async -> Result<Void, ConfigForgeError> {
        // Get the YAML content from the source file
        guard let contentToRestore = configFile.yamlContent else {
            return .failure(.configRead("无法读取要恢复的配置文件内容: \(configFile.fileName)"))
        }

        // Don't restore if content is empty (unless it's intentional)
        guard !contentToRestore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.validation("无法恢复空的配置文件: \(configFile.fileName)"))
        }

        do {
            // 1. Create backup of the current active config *before* overwriting
            let backupResult = await createDefaultBackup()
            if case .failure(let error) = backupResult {
                // Log error but proceed with restore? Or fail? Let's fail for safety.
                print("创建备份失败，恢复中止: \(error.localizedDescription)")
                return .failure(.configWrite("恢复前创建备份失败: \(error.localizedDescription)"))
            }
            
            // 2. 添加识别注释到配置内容
            var modifiedContent = contentToRestore
            
            // 移除任何现有的ConfigForge注释
            let lines = modifiedContent.components(separatedBy: .newlines)
            var filteredLines = lines.filter { !$0.contains("# ConfigForge-ActiveConfig:") }
            
            // 添加新的标识注释
            let identifierComment = "# ConfigForge-ActiveConfig: \(configFile.fileName)"
            
            // 如果第一行是注释，在其后添加；否则在开头添加
            if !filteredLines.isEmpty && filteredLines[0].hasPrefix("#") {
                filteredLines.insert(identifierComment, at: 1)
            } else {
                filteredLines.insert(identifierComment, at: 0)
            }
            
            modifiedContent = filteredLines.joined(separator: "\n")
            
            // 3. Write the restored content to the main config file
            //    saveConfig handles writing and potential errors
            let saveResult = saveConfig(content: modifiedContent)
            
            switch saveResult {
            case .success:
                return .success(())
            case .failure(let error):
                // If saving the restored content fails, return the error
                return .failure(error)
            }
            
        } catch {
            // Catch potential errors from saveConfig if it throws (though it returns Result)
            // Or other unexpected errors
            return .failure(.configWrite("恢复配置文件时发生未知错误: \(error.localizedDescription)"))
        }
    }
    
    /// 获取所有备份文件
    /// - Returns: 备份文件列表或错误
    func getBackupFiles() async -> Result<[KubeConfigFile], ConfigForgeError> {
        do {
            // 获取目录URL
            let configsDir = try getConfigsDirectoryPath()
            
            // 列出 configs 目录中的所有文件
            let directoryContents = try fileManager.contentsOfDirectory(at: configsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            
            // 筛选出备份文件 (文件名以 "backup-" 开头)
            let backupFiles = directoryContents.filter { url in
                let fileName = url.lastPathComponent
                return fileName.starts(with: "backup-")
            }
            
            // 为每个备份文件创建 KubeConfigFile 对象
            var backupFileObjects = [KubeConfigFile]()
            for fileURL in backupFiles {
                if let configFile = KubeConfigFile.from(url: fileURL, fileType: .stored) {
                    backupFileObjects.append(configFile)
                }
            }
            
            // 添加默认备份文件
            let defaultBackupPath = try getConfigBackupFilePath()
            if fileManager.fileExists(atPath: defaultBackupPath.path),
               let backupFile = KubeConfigFile.from(url: defaultBackupPath, fileType: .backup) {
                backupFileObjects.append(backupFile)
            }
            
            return .success(backupFileObjects)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.fileAccess("获取备份文件列表失败: \(error.localizedDescription)"))
        }
    }
    
    /// 删除备份文件
    /// - Parameter backupFile: 要删除的备份文件
    /// - Returns: 删除操作的结果
    func deleteBackupFile(_ backupFile: KubeConfigFile) -> Result<Void, ConfigForgeError> {
        do {
            // 仅允许删除备份类型的文件
            guard backupFile.fileType == .backup || 
                  (backupFile.fileType == .stored && backupFile.fileName.starts(with: "backup-")) else {
                return .failure(.fileAccess("只能删除备份文件"))
            }
            
            // 删除文件
            try fileManager.removeItem(at: backupFile.filePath)
            return .success(())
            
        } catch {
            return .failure(.fileAccess("删除备份文件失败: \(error.localizedDescription)"))
        }
    }
    
    // MARK: - 配置切换服务
    
    /// 将指定的配置文件设置为活动配置
    /// - Parameter configFile: 要激活的配置文件
    /// - Returns: 切换结果
    func switchToConfig(_ configFile: KubeConfigFile) async -> Result<Void, ConfigForgeError> {
        // 使用恢复逻辑，它会添加特殊注释来标识活动配置
        return await restoreConfigFile(configFile)
    }
    
    /// 创建新的配置文件
    /// - Parameters:
    ///   - content: 配置内容的 YAML 字符串
    ///   - fileName: 文件名 (将自动添加 .yaml if needed)
    /// - Returns: 创建结果，成功时返回新创建的配置文件
    func createConfigFile(content: String, fileName: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            // 确保目录存在
            try ensureConfigsDirectoryExists()
            
            // 创建文件路径
            let configsDir = try getConfigsDirectoryPath()
            
            // 确保文件名有 .yaml 扩展名
            var finalFileName = fileName
            if !fileName.lowercased().hasSuffix(".yaml") && !fileName.lowercased().hasSuffix(".yml") {
                finalFileName = "\\(fileName).yaml"
            }
            
            let filePath = configsDir.appendingPathComponent(finalFileName)
            
            // 检查文件是否已存在
            if fileManager.fileExists(atPath: filePath.path) {
                return .failure(.fileAccess("文件 \'\\(finalFileName)\' 已存在"))
            }
            
            // 写入 YAML 内容字符串
            let writeResult = fileUtils.writeFile(content: content, to: filePath, createBackup: false) // No backup for new files
            
            switch writeResult {
            case .success:
                 // 创建配置文件对象 (KubeConfigFile.from reads content and attributes)
                 guard let newConfigFile = KubeConfigFile.from(url: filePath, fileType: .stored) else {
                     // This should ideally not happen if writing succeeded and file exists
                     return .failure(.unknown("创建文件后无法为其创建配置文件对象"))
                 }
                 // The status will be .unknown initially, requiring separate validation later
                 return .success(newConfigFile)
                 
            case .failure(let error):
                // Propagate write error
                return .failure(error)
            }
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("创建配置文件失败: \\\\(error.localizedDescription)"))
        }
    }
    
    /// 更新配置文件内容
    /// - Parameters:
    ///   - configFile: 要更新的配置文件
    ///   - content: 新的 YAML 内容字符串
    /// - Returns: 更新结果，成功时返回更新后的配置文件
    func updateConfigFile(_ configFile: KubeConfigFile, with content: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            // 如果是主配置文件，先创建备份
            if configFile.fileType == .active {
                let backupResult = await createDefaultBackup()
                if case .failure(let error) = backupResult {
                    // Log error but proceed with update? Or fail? Let's fail for safety.
                     print("更新活动配置前创建备份失败，更新中止: \\(error.localizedDescription)")
                     return .failure(.configWrite("更新前创建备份失败: \\(error.localizedDescription)"))
                }
            }
            
            // 写入新的 YAML 内容
            // Use fileUtils directly to avoid creating another backup via saveConfig
             let writeResult = fileUtils.writeFile(content: content, to: configFile.filePath, createBackup: false)

             switch writeResult {
             case .success:
                 // Create an updated KubeConfigFile instance reflecting the change
                 var updatedConfigFile = configFile
                 updatedConfigFile.updateYamlContent(content) // Updates content and modification date, sets status to unknown

                 // Re-fetch modification date just to be precise, though updateYamlContent sets it
                  if let attributes = try? fileManager.attributesOfItem(atPath: configFile.filePath.path),
                     let modDate = attributes[.modificationDate] as? Date {
                      updatedConfigFile = KubeConfigFile(
                         fileName: updatedConfigFile.fileName,
                         filePath: updatedConfigFile.filePath,
                         fileType: updatedConfigFile.fileType,
                         yamlContent: updatedConfigFile.yamlContent, // Already updated
                         creationDate: updatedConfigFile.creationDate,
                         modificationDate: modDate // Use actual mod date from FS
                     )
                  }

                 return .success(updatedConfigFile)

             case .failure(let error):
                  return .failure(error) // Propagate write error
             }

        } catch let error as ConfigForgeError {
             return .failure(error)
        } catch {
             return .failure(.configWrite("更新配置文件失败: \\\\(error.localizedDescription)"))
        }
    }
    
    /// 复制配置文件
    /// - Parameters:
    ///   - configFile: 要复制的配置文件
    ///   - newFileName: 新文件名
    /// - Returns: 复制结果，成功时返回新的配置文件
    func duplicateConfigFile(_ configFile: KubeConfigFile, newFileName: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        // Get the content from the source file
        guard let contentToDuplicate = configFile.yamlContent else {
            // If content is nil, it might mean the file was unreadable initially.
            // We probably shouldn't duplicate an unreadable/empty file.
            return .failure(.configRead("无法读取源配置文件内容以进行复制: \\(configFile.fileName)"))
        }

        // Create a new file with the duplicated content
        return await createConfigFile(content: contentToDuplicate, fileName: newFileName)
    }
    
    /// 重命名配置文件
    /// - Parameters:
    ///   - configFile: 要重命名的配置文件
    ///   - newFileName: 新文件名
    /// - Returns: 重命名结果，成功时返回更新后的配置文件
    func renameConfigFile(_ configFile: KubeConfigFile, to newFileName: String) -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            // 只能重命名存储的配置文件
            guard configFile.fileType == .stored else {
                return .failure(.fileAccess("只能重命名存储的配置文件"))
            }
            
            // 获取目录URL
            let configsDir = try getConfigsDirectoryPath()
            
            // 确保文件名有 .yaml 扩展名
            var finalFileName = newFileName
            if !newFileName.lowercased().hasSuffix(".yaml") && !newFileName.lowercased().hasSuffix(".yml") {
                finalFileName = "\\(newFileName).yaml"
            }
            
            // 创建新文件路径
            let newFilePath = configsDir.appendingPathComponent(finalFileName)
            
            // 检查文件是否已存在
            if fileManager.fileExists(atPath: newFilePath.path) {
                return .failure(.fileAccess("文件 \'\\(finalFileName)\' 已存在"))
            }
            
            // 重命名文件
            try fileManager.moveItem(at: configFile.filePath, to: newFilePath)
            
            // 创建更新后的配置文件对象 (Pass the existing yamlContent)
            let renamedFile = KubeConfigFile(
                fileName: finalFileName,
                filePath: newFilePath,
                fileType: configFile.fileType, // Remains stored
                yamlContent: configFile.yamlContent, // Keep the original content
                creationDate: configFile.creationDate,
                modificationDate: Date() // Update modification date to now
            )
            
            return .success(renamedFile)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.fileAccess("重命名配置文件失败: \\\\(error.localizedDescription)"))
        }
    }
    
    /// 删除配置文件
    /// - Parameter configFile: 要删除的配置文件
    /// - Returns: 删除操作的结果
    func deleteConfigFile(_ configFile: KubeConfigFile) -> Result<Void, ConfigForgeError> {
        do {
            // 只能删除存储的配置文件
            guard configFile.fileType == .stored else {
                return .failure(.fileAccess("只能删除存储的配置文件"))
            }
            
            // 删除文件
            try fileManager.removeItem(at: configFile.filePath)
            return .success(())
            
        } catch {
            return .failure(.fileAccess("删除配置文件失败: \(error.localizedDescription)"))
        }
    }
}
