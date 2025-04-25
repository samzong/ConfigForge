import Foundation

// MARK: - KubeConfigFileManager Class

class KubeConfigFileManager {

    private let fileManager: FileManager
    private let parser: KubeConfigParser
    private let fileUtils: FileSystemUtils
    private let configDirectoryName = ".kube"
    private let configFileName = "config"
    private let configsDirectoryName = "configs"
    private let backupFileName = "config.bak"

    init(fileManager: FileManager = .default, 
         parser: KubeConfigParser = KubeConfigParser(),
         fileUtils: FileSystemUtils = FileSystemUtils.shared) {
        self.fileManager = fileManager
        self.parser = parser
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


    /// Loads the KubeConfig object from the default path (~/.kube/config).
    /// If the file doesn't exist, it returns a default empty KubeConfig object.
    /// - Returns: A `Result` containing the loaded or default `KubeConfig`, or a `ConfigForgeError`.
    func loadConfig() -> Result<KubeConfig, ConfigForgeError> {
        do {
            let configPath = try getConfigFilePath()

            // 使用 FileSystemUtils 检查文件是否存在
            guard fileManager.fileExists(atPath: configPath.path) else {
                // File doesn't exist, return a default empty config
                return .success(KubeConfig(apiVersion: nil, kind: nil, preferences: nil, clusters: [], contexts: [], users: [], currentContext: nil))
            }

            // 使用 FileSystemUtils 读取文件
            let readResult = fileUtils.readFile(at: configPath)
            switch readResult {
            case .success(let yamlString):
                // 使用解析器解码
                let parseResult = parser.decode(from: yamlString)
                switch parseResult {
                case .success(let config):
                    return .success(config)
                case .failure(let error):
                    return .failure(error)
                }
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

            // 使用 FileSystemUtils 写入文件
            return fileUtils.writeFile(content: yamlString, to: configPath, createBackup: true)

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
        
        // 使用 FileSystemUtils 写入文件
        let writeResult = fileUtils.writeFile(content: yamlString, to: destination)
        
        if case .failure(let error) = writeResult {
            throw error
        }
    }

    /// Restores the Kubeconfig from the specified URL.
    /// - Parameter source: The source URL of the backup file
    /// - Returns: The restored KubeConfig object
    func restoreConfig(from source: URL) async throws -> KubeConfig {
        // 使用 FileSystemUtils 读取文件
        let readResult = fileUtils.readFile(at: source)
        switch readResult {
        case .success(let yamlString):
            // 解析内容
            let parseResult = parser.decode(from: yamlString)
            switch parseResult {
            case .success(let config):
                // 也写回默认位置
                let configPath = try getConfigFilePath()
                let writeResult = fileUtils.writeFile(content: yamlString, to: configPath)
                
                if case .failure(let error) = writeResult {
                    throw error
                }
                
                return config
            case .failure(let error):
                throw error
            }
            
        case .failure(let error):
            throw error
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
                try await backupConfig(config: config, to: backupPath)
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
            
            // 获取主配置文件和备份文件
            var configFiles = [KubeConfigFile]()
            
            // 检查主配置文件
            let mainConfigPath = try getConfigFilePath()
            if fileManager.fileExists(atPath: mainConfigPath.path),
               let mainConfigFile = KubeConfigFile.from(url: mainConfigPath, fileType: .active) {
                configFiles.append(mainConfigFile)
            }
            
            // 检查备份文件
            let backupPath = try getConfigBackupFilePath()
            if fileManager.fileExists(atPath: backupPath.path),
               let backupFile = KubeConfigFile.from(url: backupPath, fileType: .backup) {
                configFiles.append(backupFile)
            }
            
            // 列出 configs 目录中的所有文件
            let directoryContents = try fileManager.contentsOfDirectory(at: configsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            
            // 筛选出 YAML 和 YML 文件
            let yamlFiles = directoryContents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return fileExtension == "yaml" || fileExtension == "yml"
            }
            
            // 为每个文件创建 KubeConfigFile 对象
            for fileURL in yamlFiles {
                if let configFile = KubeConfigFile.from(url: fileURL, fileType: .stored) {
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
    
    /// 加载并验证配置文件的内容
    /// - Parameter configFile: 要加载的配置文件
    /// - Returns: 更新后的配置文件对象或错误
    func loadAndValidateConfigFile(_ configFile: KubeConfigFile) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            var updatedConfigFile = configFile
            
            // 读取文件内容
            let yamlString = try String(contentsOf: configFile.filePath, encoding: .utf8)
            
            // 使用解析器解码
            let parseResult = parser.decode(from: yamlString)
            switch parseResult {
            case .success(let config):
                // 验证配置结构
                let validationResult = await validateKubeConfig(config)
                switch validationResult {
                case .success(_):
                    updatedConfigFile.updateConfig(config)
                    return .success(updatedConfigFile)
                case .failure(let error):
                    updatedConfigFile.markAsInvalid(error.localizedDescription)
                    return .success(updatedConfigFile) // 返回标记为无效的文件
                }
                
            case .failure(let error):
                updatedConfigFile.markAsInvalid(error.localizedDescription)
                return .success(updatedConfigFile) // 返回标记为无效的文件
            }
            
        } catch {
            return .failure(.configRead("读取配置文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 验证 KubeConfig 对象的有效性
    /// - Parameter config: 要验证的配置
    /// - Returns: 验证结果
    private func validateKubeConfig(_ config: KubeConfig) async -> Result<Void, ConfigForgeError> {
        // 基本结构验证
        if config.clusters?.isEmpty ?? true {
            return .failure(.validation("配置缺少集群定义"))
        }
        
        if config.contexts?.isEmpty ?? true {
            return .failure(.validation("配置缺少上下文定义"))
        }
        
        if config.users?.isEmpty ?? true {
            return .failure(.validation("配置缺少用户定义"))
        }
        
        // 检查当前上下文是否在定义的上下文中
        if let currentContext = config.currentContext {
            let contextExists = config.contexts?.contains { $0.name == currentContext } ?? false
            if !contextExists {
                return .failure(.validation("当前上下文 '\(currentContext)' 未在配置中定义"))
            }
        }
        
        // 验证上下文引用的集群和用户是否存在
        for context in config.contexts ?? [] {
            let clusterName = context.context.cluster
            let clusterExists = config.clusters?.contains { $0.name == clusterName } ?? false
            if !clusterExists {
                return .failure(.validation("上下文 '\(context.name)' 引用了未定义的集群 '\(clusterName)'"))
            }
            
            // user属性是非可选类型，直接使用
            let userName = context.context.user
            let userExists = config.users?.contains { $0.name == userName } ?? false
            if !userExists {
                return .failure(.validation("上下文 '\(context.name)' 引用了未定义的用户 '\(userName)'"))
            }
        }
        
        return .success(())
    }
    
    /// 批量加载多个配置文件
    /// - Parameter configFiles: 要加载的配置文件列表
    /// - Returns: 加载后的配置文件列表或错误
    func loadConfigFiles(_ configFiles: [KubeConfigFile]) async -> Result<[KubeConfigFile], ConfigForgeError> {
        var loadedFiles = [KubeConfigFile]()
        
        for configFile in configFiles {
            let result = await loadAndValidateConfigFile(configFile)
            switch result {
            case .success(let loadedFile):
                loadedFiles.append(loadedFile)
            case .failure(let error):
                print("加载配置文件 \(configFile.fileName) 失败: \(error.localizedDescription)")
                // 继续处理其他文件，但标记当前文件为无效
                var errorFile = configFile
                errorFile.markAsInvalid(error.localizedDescription)
                loadedFiles.append(errorFile)
            }
        }
        
        return .success(loadedFiles)
    }
    
    // MARK: - 增强备份功能
    
    /// 使用时间戳创建自定义备份文件
    /// - Parameters:
    ///   - config: 要备份的配置
    ///   - customName: 可选的自定义名称 (默认使用时间戳)
    /// - Returns: 备份操作的结果，成功时返回备份文件路径
    func createCustomBackup(config: KubeConfig, customName: String? = nil) async -> Result<URL, ConfigForgeError> {
        do {
            // 确保目录存在
            try ensureConfigsDirectoryExists()
            
            // 生成文件名 (使用时间戳或自定义名称)
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: ".", with: "-")
            
            let backupFileName: String
            if let customName = customName {
                backupFileName = "backup-\(customName).yaml"
            } else {
                backupFileName = "backup-\(timestamp).yaml"
            }
            
            // 创建备份文件路径
            let configsDir = try getConfigsDirectoryPath()
            let backupPath = configsDir.appendingPathComponent(backupFileName)
            
            // 备份配置
            try await backupConfig(config: config, to: backupPath)
            
            return .success(backupPath)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("创建自定义备份失败: \(error.localizedDescription)"))
        }
    }
    
    /// 恢复配置到主配置文件并创建备份
    /// - Parameter configFile: 要恢复的配置文件
    /// - Returns: 恢复操作的结果
    func restoreConfigFile(_ configFile: KubeConfigFile) async -> Result<Void, ConfigForgeError> {
        do {
            // 首先检查文件是否有效
            guard let config = configFile.config else {
                // 需要先加载文件
                let loadResult = await loadAndValidateConfigFile(configFile)
                switch loadResult {
                case .success(let loadedFile):
                    guard let loadedConfig = loadedFile.config, loadedFile.status == .valid else {
                        return .failure(.validation("无法恢复无效的配置文件"))
                    }
                    
                    // 在切换前创建备份
                    let backupResult = await createDefaultBackup()
                    if case .failure(let error) = backupResult {
                        // 只记录错误，继续恢复过程
                        print("创建备份失败: \(error.localizedDescription)")
                    }
                    
                    // 将配置写入主配置文件
                    let configPath = try getConfigFilePath()
                    try await backupConfig(config: loadedConfig, to: configPath)
                    return .success(())
                    
                case .failure(let error):
                    return .failure(error)
                }
            }
            
            // 文件已加载，直接使用
            // 在切换前创建备份
            let backupResult = await createDefaultBackup()
            if case .failure(let error) = backupResult {
                // 只记录错误，继续恢复过程
                print("创建备份失败: \(error.localizedDescription)")
            }
            
            // 将配置写入主配置文件
            let configPath = try getConfigFilePath()
            try await backupConfig(config: config, to: configPath)
            return .success(())
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("恢复配置文件失败: \(error.localizedDescription)"))
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
        // 与 restoreConfigFile 类似但有一些差异
        return await restoreConfigFile(configFile)
    }
    
    /// 创建新的配置文件
    /// - Parameters:
    ///   - config: 配置内容
    ///   - fileName: 文件名
    /// - Returns: 创建结果，成功时返回新创建的配置文件
    func createConfigFile(config: KubeConfig, fileName: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            // 确保目录存在
            try ensureConfigsDirectoryExists()
            
            // 创建文件路径
            let configsDir = try getConfigsDirectoryPath()
            
            // 确保文件名有 .yaml 扩展名
            var finalFileName = fileName
            if !fileName.lowercased().hasSuffix(".yaml") && !fileName.lowercased().hasSuffix(".yml") {
                finalFileName = "\(fileName).yaml"
            }
            
            let filePath = configsDir.appendingPathComponent(finalFileName)
            
            // 检查文件是否已存在
            if fileManager.fileExists(atPath: filePath.path) {
                return .failure(.fileAccess("文件 '\(finalFileName)' 已存在"))
            }
            
            // 编码配置
            let encodeResult = parser.encode(config: config)
            let yamlString: String
            
            switch encodeResult {
            case .success(let encodedString):
                yamlString = encodedString
            case .failure(let error):
                return .failure(error)
            }
            
            // 写入文件
            try yamlString.write(to: filePath, atomically: true, encoding: .utf8)
            
            // 创建配置文件对象
            guard let configFile = KubeConfigFile.from(url: filePath, fileType: .stored) else {
                return .failure(.unknown("创建配置文件对象失败"))
            }
            
            // 设置配置和状态
            var newConfigFile = configFile
            newConfigFile.updateConfig(config)
            
            return .success(newConfigFile)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("创建配置文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 更新配置文件内容
    /// - Parameters:
    ///   - configFile: 要更新的配置文件
    ///   - config: 新的配置内容
    /// - Returns: 更新结果，成功时返回更新后的配置文件
    func updateConfigFile(_ configFile: KubeConfigFile, with config: KubeConfig) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            // 如果是主配置文件，先创建备份
            if configFile.fileType == .active {
                let backupResult = await createDefaultBackup()
                if case .failure(let error) = backupResult {
                    // 只记录错误，继续更新
                    print("创建备份失败: \(error.localizedDescription)")
                }
            }
            
            // 编码配置
            let encodeResult = parser.encode(config: config)
            let yamlString: String
            
            switch encodeResult {
            case .success(let encodedString):
                yamlString = encodedString
            case .failure(let error):
                return .failure(error)
            }
            
            // 写入文件
            try yamlString.write(to: configFile.filePath, atomically: true, encoding: .utf8)
            
            // 创建更新后的配置文件对象
            var updatedConfigFile = configFile
            updatedConfigFile.updateConfig(config)
            
            // 更新修改日期
            if let attributes = try? fileManager.attributesOfItem(atPath: configFile.filePath.path),
               let modDate = attributes[.modificationDate] as? Date {
                updatedConfigFile = KubeConfigFile(
                    fileName: configFile.fileName,
                    filePath: configFile.filePath,
                    fileType: configFile.fileType,
                    config: config,
                    creationDate: configFile.creationDate,
                    modificationDate: modDate
                )
            }
            
            return .success(updatedConfigFile)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("更新配置文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 复制配置文件
    /// - Parameters:
    ///   - configFile: 要复制的配置文件
    ///   - newFileName: 新文件名
    /// - Returns: 复制结果，成功时返回新的配置文件
    func duplicateConfigFile(_ configFile: KubeConfigFile, newFileName: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            // 首先确保配置已加载
            let loadedConfigFile: KubeConfigFile
            if configFile.config == nil {
                let loadResult = await loadAndValidateConfigFile(configFile)
                switch loadResult {
                case .success(let file):
                    loadedConfigFile = file
                case .failure(let error):
                    return .failure(error)
                }
            } else {
                loadedConfigFile = configFile
            }
            
            // 检查文件是否存在配置
            guard let config = loadedConfigFile.config else {
                return .failure(.validation("无法复制无效的配置文件"))
            }
            
            // 创建新文件
            return await createConfigFile(config: config, fileName: newFileName)
            
        } catch {
            return .failure(.unknown("复制配置文件失败: \(error.localizedDescription)"))
        }
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
                finalFileName = "\(newFileName).yaml"
            }
            
            // 创建新文件路径
            let newFilePath = configsDir.appendingPathComponent(finalFileName)
            
            // 检查文件是否已存在
            if fileManager.fileExists(atPath: newFilePath.path) {
                return .failure(.fileAccess("文件 '\(finalFileName)' 已存在"))
            }
            
            // 重命名文件
            try fileManager.moveItem(at: configFile.filePath, to: newFilePath)
            
            // 创建更新后的配置文件对象
            let renamedFile = KubeConfigFile(
                fileName: finalFileName,
                filePath: newFilePath,
                fileType: configFile.fileType,
                config: configFile.config,
                creationDate: configFile.creationDate,
                modificationDate: Date()
            )
            
            return .success(renamedFile)
            
        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.fileAccess("重命名配置文件失败: \(error.localizedDescription)"))
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
