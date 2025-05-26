import Foundation

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

    func getConfigFilePath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName).appendingPathComponent(configFileName)
    }

    func getConfigBackupFilePath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName).appendingPathComponent(backupFileName)
    }

    func getConfigDirectoryPath() throws -> URL {
        let homeDirectory = fileManager.homeDirectoryForCurrentUser
        return homeDirectory.appendingPathComponent(configDirectoryName)
    }

    func getConfigsDirectoryPath() throws -> URL {
        let configDirURL = try getConfigDirectoryPath()
        return configDirURL.appendingPathComponent(configsDirectoryName)
    }

    private func ensureConfigDirectoryExists() throws {
        let directoryURL = try getConfigDirectoryPath()
        let result = fileUtils.createDirectoryIfNeeded(at: directoryURL)

        if case .failure(let error) = result {
            throw error
        }
    }

    func ensureConfigsDirectoryExists() throws {
        let directoryURL = try getConfigsDirectoryPath()
        let result = fileUtils.createDirectoryIfNeeded(at: directoryURL)

        if case .failure(let error) = result {
            throw error
        }
    }

    func loadConfig() -> Result<String, ConfigForgeError> {
        do {
            let configPath = try getConfigFilePath()
            guard fileManager.fileExists(atPath: configPath.path) else {
                return .success("")
            }
            let readResult = fileUtils.readFile(at: configPath)
            switch readResult {
            case .success(let yamlString):
                return .success(yamlString)
            case .failure(let error):
                return .failure(error) 
            }

        } catch let error as ConfigForgeError {
            return .failure(error) 
        } catch {
            return .failure(.configRead("读取 Kubeconfig 文件失败: \\(error.localizedDescription)"))
        }
    }

    func saveConfig(content: String) -> Result<Void, ConfigForgeError> {
        do {
            try ensureConfigDirectoryExists()

            let configPath = try getConfigFilePath()
            return fileUtils.writeFile(content: content, to: configPath, createBackup: true)

        } catch let error as ConfigForgeError {
            return .failure(error) 
        } catch {
            return .failure(.configWrite("写入 Kubeconfig 文件失败: \\(error.localizedDescription)"))
        }
    }

    func backupConfig(content: String, to destination: URL) async throws {
        let writeResult = fileUtils.writeFile(content: content, to: destination)

        if case .failure(let error) = writeResult {
            throw error
        }
    }

    func restoreConfig(from source: URL) async -> Result<String, ConfigForgeError> {
        let readResult = fileUtils.readFile(at: source)

        switch readResult {
        case .success(let yamlString):
            do {
                let configPath = try getConfigFilePath()
                let writeResult = fileUtils.writeFile(content: yamlString, to: configPath, createBackup: false) 

                if case .failure(let error) = writeResult {
                    return .failure(error) 
                }
                return .success(yamlString)

            } catch let error as ConfigForgeError {
                return .failure(error) 
            } catch {
                return .failure(.configWrite("恢复过程中写回 Kubeconfig 文件失败: \\(error.localizedDescription)"))
            }

        case .failure(let error):
            return .failure(error)
        }
    }

    func createDefaultBackup() async -> Result<Void, ConfigForgeError> {
        do {
            let loadResult = loadConfig()

            switch loadResult {
            case .success(let config):
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

    func discoverConfigFiles() async -> Result<[KubeConfigFile], ConfigForgeError> {
        do {
            try ensureConfigsDirectoryExists()
            let configsDir = try getConfigsDirectoryPath()
            let mainConfigPath = try getConfigFilePath()
            var activeConfigIdentifier: String? = nil

            if fileManager.fileExists(atPath: mainConfigPath.path) {
                do {
                    let mainConfigContent = try String(contentsOf: mainConfigPath, encoding: .utf8)
                    if let range = mainConfigContent.range(of: "# ConfigForge-ActiveConfig: .*", options: .regularExpression) {
                        let commentLine = String(mainConfigContent[range])
                        if let filenameRange = commentLine.range(of: "(?<=# ConfigForge-ActiveConfig: ).*", options: .regularExpression) {
                            activeConfigIdentifier = String(commentLine[filenameRange])
                        }
                    }
                } catch {
                    print("Warning: Could not read active config: \(error.localizedDescription)")
                }
            }
            var configFiles = [KubeConfigFile]()
            let directoryContents = try fileManager.contentsOfDirectory(at: configsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            let yamlFiles = directoryContents.filter { url in
                let fileExtension = url.pathExtension.lowercased()
                return fileExtension == "yaml" || fileExtension == "yml"
            }
            for fileURL in yamlFiles {
                let isActive = activeConfigIdentifier != nil && 
                    fileURL.lastPathComponent == activeConfigIdentifier
                if var configFile = KubeConfigFile.from(url: fileURL, fileType: .stored) {
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

    func createCustomBackup(content: String, customName: String? = nil) async -> Result<URL, ConfigForgeError> {
        do {
            try ensureConfigsDirectoryExists()
            let timestamp = ISO8601DateFormatter().string(from: Date())
                .replacingOccurrences(of: ":", with: "-")
                .replacingOccurrences(of: ".", with: "-") 

            let backupFileName: String
            if let customName = customName, !customName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                let sanitizedName = customName.replacingOccurrences(of: "/", with: "-")
                    .replacingOccurrences(of: "\\\\", with: "-")
                backupFileName = "backup-\(sanitizedName).yaml"
            } else {
                backupFileName = "backup-\(timestamp).yaml"
            }
            let configsDir = try getConfigsDirectoryPath()
            let backupPath = configsDir.appendingPathComponent(backupFileName)
            try await backupConfig(content: content, to: backupPath)

            return .success(backupPath)

        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("创建自定义备份失败: \\\\(error.localizedDescription)"))
        }
    }

    func restoreConfigFile(_ configFile: KubeConfigFile) async -> Result<Void, ConfigForgeError> {
        guard let contentToRestore = configFile.yamlContent else {
            return .failure(.configRead("无法读取要恢复的配置文件内容: \(configFile.fileName)"))
        }
        guard !contentToRestore.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .failure(.validation("无法恢复空的配置文件: \(configFile.fileName)"))
        }

        do {
            let backupResult = await createDefaultBackup()
            if case .failure(let error) = backupResult {
                print("创建备份失败，恢复中止: \(error.localizedDescription)")
                return .failure(.configWrite("恢复前创建备份失败: \(error.localizedDescription)"))
            }
            var modifiedContent = contentToRestore
            let lines = modifiedContent.components(separatedBy: .newlines)
            var filteredLines = lines.filter { !$0.contains("# ConfigForge-ActiveConfig:") }
            let identifierComment = "# ConfigForge-ActiveConfig: \(configFile.fileName)"
            if !filteredLines.isEmpty && filteredLines[0].hasPrefix("#") {
                filteredLines.insert(identifierComment, at: 1)
            } else {
                filteredLines.insert(identifierComment, at: 0)
            }

            modifiedContent = filteredLines.joined(separator: "\n")
            let saveResult = saveConfig(content: modifiedContent)

            switch saveResult {
            case .success:
                return .success(())
            case .failure(let error):
                return .failure(error)
            }

        } catch {
            // This catch block is unreachable because no errors are thrown in 'do' block
            // But keeping it for future error handling if needed
            return .failure(.configWrite("恢复配置文件时发生未知错误: \(error.localizedDescription)"))
        }
    }

    func getBackupFiles() async -> Result<[KubeConfigFile], ConfigForgeError> {
        do {
            let configsDir = try getConfigsDirectoryPath()
            let directoryContents = try fileManager.contentsOfDirectory(at: configsDir, includingPropertiesForKeys: [.creationDateKey, .contentModificationDateKey], options: [.skipsHiddenFiles])
            let backupFiles = directoryContents.filter { url in
                let fileName = url.lastPathComponent
                return fileName.starts(with: "backup-")
            }
            var backupFileObjects = [KubeConfigFile]()
            for fileURL in backupFiles {
                if let configFile = KubeConfigFile.from(url: fileURL, fileType: .stored) {
                    backupFileObjects.append(configFile)
                }
            }
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

    func deleteBackupFile(_ backupFile: KubeConfigFile) -> Result<Void, ConfigForgeError> {
        do {
            guard backupFile.fileType == .backup || 
                (backupFile.fileType == .stored && backupFile.fileName.starts(with: "backup-")) else {
                return .failure(.fileAccess("只能删除备份文件"))
            }
            try fileManager.removeItem(at: backupFile.filePath)
            return .success(())

        } catch {
            return .failure(.fileAccess("删除备份文件失败: \(error.localizedDescription)"))
        }
    }

    func switchToConfig(_ configFile: KubeConfigFile) async -> Result<Void, ConfigForgeError> {
        return await restoreConfigFile(configFile)
    }

    func createConfigFile(content: String, fileName: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            try ensureConfigsDirectoryExists()
            let configsDir = try getConfigsDirectoryPath()
            var finalFileName = fileName
            if !fileName.lowercased().hasSuffix(".yaml") && !fileName.lowercased().hasSuffix(".yml") {
                finalFileName = "\\(fileName).yaml"
            }

            let filePath = configsDir.appendingPathComponent(finalFileName)
            if fileManager.fileExists(atPath: filePath.path) {
                return .failure(.fileAccess("文件 \'\\(finalFileName)\' 已存在"))
            }
            let writeResult = fileUtils.writeFile(content: content, to: filePath, createBackup: false) 

            switch writeResult {
            case .success:
                guard let newConfigFile = KubeConfigFile.from(url: filePath, fileType: .stored) else {
                    return .failure(.unknown("创建文件后无法为其创建配置文件对象"))
                }
                return .success(newConfigFile)

            case .failure(let error):
                return .failure(error)
            }

        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("创建配置文件失败: \\\\(error.localizedDescription)"))
        }
    }

    func updateConfigFile(_ configFile: KubeConfigFile, with content: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            if configFile.fileType == .active {
                let backupResult = await createDefaultBackup()
                if case .failure(let error) = backupResult {
                    print("更新活动配置前创建备份失败，更新中止: \(error.localizedDescription)")
                    return .failure(.configWrite("更新前创建备份失败: \(error.localizedDescription)"))
                }
            }
            let writeResult = fileUtils.writeFile(content: content, to: configFile.filePath, createBackup: false)

            switch writeResult {
            case .success:
                var updatedConfigFile = configFile
                updatedConfigFile.updateYamlContent(content) 
                if let attributes = try? fileManager.attributesOfItem(atPath: configFile.filePath.path),
                   let modDate = attributes[.modificationDate] as? Date {
                    updatedConfigFile = KubeConfigFile(
                        fileName: updatedConfigFile.fileName,
                        filePath: updatedConfigFile.filePath,
                        fileType: updatedConfigFile.fileType,
                        yamlContent: updatedConfigFile.yamlContent, 
                        creationDate: updatedConfigFile.creationDate,
                        modificationDate: modDate 
                    )
                }

                return .success(updatedConfigFile)

            case .failure(let error):
                return .failure(error) 
            }

        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.configWrite("更新配置文件失败: \\\\(error.localizedDescription)"))
        }
    }

    func duplicateConfigFile(_ configFile: KubeConfigFile, newFileName: String) async -> Result<KubeConfigFile, ConfigForgeError> {
        guard let contentToDuplicate = configFile.yamlContent else {
            return .failure(.configRead("无法读取源配置文件内容以进行复制: \\(configFile.fileName)"))
        }
        return await createConfigFile(content: contentToDuplicate, fileName: newFileName)
    }

    func renameConfigFile(_ configFile: KubeConfigFile, to newFileName: String) -> Result<KubeConfigFile, ConfigForgeError> {
        do {
            guard configFile.fileType == .stored else {
                return .failure(.fileAccess("只能重命名存储的配置文件"))
            }
            let configsDir = try getConfigsDirectoryPath()
            var finalFileName = newFileName
            if !newFileName.lowercased().hasSuffix(".yaml") && !newFileName.lowercased().hasSuffix(".yml") {
                finalFileName = "\\(newFileName).yaml"
            }
            let newFilePath = configsDir.appendingPathComponent(finalFileName)
            if fileManager.fileExists(atPath: newFilePath.path) {
                return .failure(.fileAccess("文件 \'\\(finalFileName)\' 已存在"))
            }
            try fileManager.moveItem(at: configFile.filePath, to: newFilePath)
            let renamedFile = KubeConfigFile(
                fileName: finalFileName,
                filePath: newFilePath,
                fileType: configFile.fileType, 
                yamlContent: configFile.yamlContent, 
                creationDate: configFile.creationDate,
                modificationDate: Date() 
            )

            return .success(renamedFile)

        } catch let error as ConfigForgeError {
            return .failure(error)
        } catch {
            return .failure(.fileAccess("重命名配置文件失败: \\\\(error.localizedDescription)"))
        }
    }

    func deleteConfigFile(_ configFile: KubeConfigFile) -> Result<Void, ConfigForgeError> {
        do {
            guard configFile.fileType == .stored else {
                return .failure(.fileAccess("只能删除存储的配置文件"))
            }
            try fileManager.removeItem(at: configFile.filePath)
            return .success(())

        } catch {
            return .failure(.fileAccess("删除配置文件失败: \(error.localizedDescription)"))
        }
    }
}
