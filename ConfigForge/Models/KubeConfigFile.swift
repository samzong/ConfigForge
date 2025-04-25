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
    
    /// 文件的配置内容
    private(set) var config: KubeConfig?
    
    /// 文件类型 (活动、备份、存储的)
    let fileType: KubeConfigFileType
    
    /// 文件状态 (有效、无效等)
    private(set) var status: KubeConfigFileStatus = .unknown
    
    /// 文件创建日期
    let creationDate: Date?
    
    /// 文件最后修改日期
    var modificationDate: Date?
    
    /// 创建配置文件对象
    /// - Parameters:
    ///   - fileName: 文件名
    ///   - filePath: 文件路径
    ///   - fileType: 文件类型
    ///   - config: 配置内容 (如果已加载)
    ///   - creationDate: 创建日期
    ///   - modificationDate: 修改日期
    init(fileName: String, filePath: URL, fileType: KubeConfigFileType, config: KubeConfig? = nil, 
         creationDate: Date? = nil, modificationDate: Date? = nil) {
        self.fileName = fileName
        self.filePath = filePath
        self.fileType = fileType
        self.config = config
        self.creationDate = creationDate
        self.modificationDate = modificationDate
    }
    
    /// 使用文件属性从文件路径创建实例
    /// - Parameters:
    ///   - url: 文件URL
    ///   - fileType: 文件类型
    ///   - fileManager: 文件管理器
    /// - Returns: 新的 KubeConfigFile 实例或 nil (如果不能获取文件属性)
    static func from(url: URL, fileType: KubeConfigFileType, fileManager: FileManager = .default) -> KubeConfigFile? {
        do {
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            let creationDate = attributes[.creationDate] as? Date
            let modificationDate = attributes[.modificationDate] as? Date
            
            return KubeConfigFile(
                fileName: url.lastPathComponent,
                filePath: url,
                fileType: fileType,
                creationDate: creationDate,
                modificationDate: modificationDate
            )
        } catch {
            print("无法读取文件属性: \(error.localizedDescription)")
            return KubeConfigFile(
                fileName: url.lastPathComponent,
                filePath: url,
                fileType: fileType
            )
        }
    }
    
    /// 更新配置内容和状态
    /// - Parameter newConfig: 新的配置内容
    mutating func updateConfig(_ newConfig: KubeConfig) {
        self.config = newConfig
        self.status = .valid
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