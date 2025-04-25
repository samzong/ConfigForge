import Foundation

/// 表示单个 Kubernetes 配置文件的状态
enum KubeConfigFileStatus: Equatable {
    /// 配置文件有效
    case valid
    /// 配置文件格式无效
    case invalid(String)
    /// 配置文件未加载或状态未知
    case unknown
}

/// 表示单个配置文件的类型
enum KubeConfigFileType: Equatable {
    /// 主配置文件 (~/.kube/config)
    case active
    /// 备份配置文件 (~/.kube/config.bak)
    case backup
    /// 存储在 ~/.kube/configs/ 目录中的配置文件
    case stored
}

/// 表示文件系统中的单个 Kubernetes 配置文件
struct KubeConfigFile: Identifiable, Equatable {
    /// 唯一标识符，基于文件路径
    var id: String { filePath.path }
    
    /// 文件名
    let fileName: String
    
    /// 显示名称 (不带扩展名)
    var displayName: String {
        fileName.components(separatedBy: ".").first ?? fileName
    }
    
    /// 完整的文件路径
    let filePath: URL
    
    /// The raw YAML content of the config file
    private(set) var yamlContent: String?
    
    /// 文件类型 (活动、备份、存储的)
    let fileType: KubeConfigFileType
    
    /// 文件状态 (有效、无效等)
    var status: KubeConfigFileStatus = .unknown
    
    /// 文件创建日期
    let creationDate: Date?
    
    /// 文件最后修改日期
    var modificationDate: Date?
    
    /// 是否为当前活动配置文件
    var isActive: Bool = false
    
    /// 创建配置文件对象
    /// - Parameters:
    ///   - fileName: 文件名
    ///   - filePath: 文件路径
    ///   - fileType: 文件类型
    ///   - yamlContent: Raw YAML content (if loaded)
    ///   - creationDate: 创建日期
    ///   - modificationDate: 修改日期
    init(fileName: String, filePath: URL, fileType: KubeConfigFileType, yamlContent: String? = nil, 
         creationDate: Date? = nil, modificationDate: Date? = nil, isActive: Bool = false) {
        self.fileName = fileName
        self.filePath = filePath
        self.fileType = fileType
        self.yamlContent = yamlContent
        self.creationDate = creationDate
        self.modificationDate = modificationDate
        self.isActive = isActive
    }
    
    /// Creates an instance from a file URL, attempting to read its content and attributes.
    /// - Parameters:
    ///   - url: The file URL.
    ///   - fileType: The type of the file.
    ///   - fileManager: FileManager instance.
    /// - Returns: A new KubeConfigFile instance, potentially with nil content if read fails.
    static func from(url: URL, fileType: KubeConfigFileType, fileManager: FileManager = .default, isActive: Bool = false) -> KubeConfigFile? {
        var creationDate: Date? = nil
        var modificationDate: Date? = nil
        var yamlContent: String? = nil

        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            creationDate = attributes[.creationDate] as? Date
            modificationDate = attributes[.modificationDate] as? Date
        } catch {
            print("Warning: Could not read file attributes for \(url.path): \(error.localizedDescription)")
        }

        do {
             yamlContent = try String(contentsOf: url, encoding: .utf8)
        } catch {
            print("Warning: Could not read file content for \(url.path): \(error.localizedDescription)")
            // Content remains nil, status remains .unknown
        }
        
        return KubeConfigFile(
            fileName: url.lastPathComponent,
            filePath: url,
            fileType: fileType,
            yamlContent: yamlContent,
            creationDate: creationDate,
            modificationDate: modificationDate,
            isActive: isActive
        )
    }
    
    /// Updates the raw YAML content and resets the status to unknown.
    /// - Parameter newContent: The new YAML content.
    mutating func updateYamlContent(_ newContent: String) {
        self.yamlContent = newContent
        self.status = .unknown // Status needs re-validation after content change
        self.modificationDate = Date() // Update modification date
    }
    
    /// 标记为无效，并提供原因
    /// - Parameter reason: 无效的原因
    mutating func markAsInvalid(_ reason: String) {
        self.status = .invalid(reason)
    }
    
    // MARK: - Equatable
    
    static func == (lhs: KubeConfigFile, rhs: KubeConfigFile) -> Bool {
        return lhs.filePath == rhs.filePath &&
               lhs.fileType == rhs.fileType
    }
} 