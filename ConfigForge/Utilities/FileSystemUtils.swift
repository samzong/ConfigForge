import Foundation

/// 文件系统工具类，提供安全的文件读写操作和权限检查
class FileSystemUtils: @unchecked Sendable {
    
    /// 共享实例
    static let shared = FileSystemUtils()
    
    /// 文件管理器
    private let fileManager: FileManager
    
    /// 私有初始化方法
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    
    /// 安全地读取文件内容
    /// - Parameter url: 文件路径
    /// - Returns: 文件内容或错误
    func readFile(at url: URL) -> Result<String, ConfigForgeError> {
        do {
            // 检查文件是否存在
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.fileAccess("文件不存在: \(url.lastPathComponent)"))
            }
            
            // 检查读取权限
            guard isFileReadable(at: url) else {
                return .failure(.fileAccess("无权限读取文件: \(url.lastPathComponent)"))
            }
            
            // 读取文件内容
            let content = try String(contentsOf: url, encoding: .utf8)
            return .success(content)
            
        } catch {
            return .failure(.configRead("读取文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 安全地写入文件内容
    /// - Parameters:
    ///   - content: 要写入的内容
    ///   - url: 文件路径
    ///   - createBackup: 是否创建备份
    /// - Returns: 操作结果
    func writeFile(content: String, to url: URL, createBackup: Bool = false) -> Result<Void, ConfigForgeError> {
        do {
            // 检查目录是否存在，不存在则创建
            let directory = url.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            
            // 如果需要创建备份
            if createBackup && fileManager.fileExists(atPath: url.path) {
                let backupURL = url.deletingLastPathComponent()
                    .appendingPathComponent(".\(url.lastPathComponent).bak")
                
                // 先删除可能存在的旧备份
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                
                // 创建备份
                try fileManager.copyItem(at: url, to: backupURL)
            }
            
            // 写入文件
            try content.write(to: url, atomically: true, encoding: .utf8)
            
            // 确保文件权限正确 (仅当前用户可读写)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            
            return .success(())
            
        } catch {
            return .failure(.configWrite("写入文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 复制文件
    /// - Parameters:
    ///   - sourceURL: 源文件路径
    ///   - destinationURL: 目标文件路径
    ///   - overwrite: 是否覆盖目标文件
    /// - Returns: 操作结果
    func copyFile(from sourceURL: URL, to destinationURL: URL, overwrite: Bool = false) -> Result<Void, ConfigForgeError> {
        do {
            // 检查源文件是否存在
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                return .failure(.fileAccess("源文件不存在: \(sourceURL.lastPathComponent)"))
            }
            
            // 检查目标文件是否存在
            if fileManager.fileExists(atPath: destinationURL.path) {
                if overwrite {
                    try fileManager.removeItem(at: destinationURL)
                } else {
                    return .failure(.fileAccess("目标文件已存在: \(destinationURL.lastPathComponent)"))
                }
            }
            
            // 复制文件
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            
            // 确保文件权限正确
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("复制文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 移动/重命名文件
    /// - Parameters:
    ///   - sourceURL: 源文件路径
    ///   - destinationURL: 目标文件路径
    /// - Returns: 操作结果
    func moveFile(from sourceURL: URL, to destinationURL: URL) -> Result<Void, ConfigForgeError> {
        do {
            // 检查源文件是否存在
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                return .failure(.fileAccess("源文件不存在: \(sourceURL.lastPathComponent)"))
            }
            
            // 检查目标文件是否存在
            if fileManager.fileExists(atPath: destinationURL.path) {
                return .failure(.fileAccess("目标文件已存在: \(destinationURL.lastPathComponent)"))
            }
            
            // 移动文件
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("移动文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 删除文件
    /// - Parameter url: 文件路径
    /// - Returns: 操作结果
    func deleteFile(at url: URL) -> Result<Void, ConfigForgeError> {
        do {
            // 检查文件是否存在
            guard fileManager.fileExists(atPath: url.path) else {
                return .success(()) // 文件不存在也算成功
            }
            
            // 删除文件
            try fileManager.removeItem(at: url)
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("删除文件失败: \(error.localizedDescription)"))
        }
    }
    
    /// 获取文件属性
    /// - Parameter url: 文件路径
    /// - Returns: 文件属性或错误
    func getFileAttributes(at url: URL) -> Result<[FileAttributeKey: Any], ConfigForgeError> {
        do {
            // 检查文件是否存在
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.fileAccess("文件不存在: \(url.lastPathComponent)"))
            }
            
            // 获取文件属性
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            
            return .success(attributes)
            
        } catch {
            return .failure(.fileAccess("获取文件属性失败: \(error.localizedDescription)"))
        }
    }
    
    /// 检查文件是否可读
    /// - Parameter url: 文件路径
    /// - Returns: 是否可读
    func isFileReadable(at url: URL) -> Bool {
        return fileManager.isReadableFile(atPath: url.path)
    }
    
    /// 检查文件是否可写
    /// - Parameter url: 文件路径
    /// - Returns: 是否可写
    func isFileWritable(at url: URL) -> Bool {
        return fileManager.isWritableFile(atPath: url.path)
    }
    
    /// 创建目录（如果不存在）
    /// - Parameter url: 目录路径
    /// - Returns: 操作结果
    func createDirectoryIfNeeded(at url: URL) -> Result<Void, ConfigForgeError> {
        do {
            // 检查目录是否存在
            if !fileManager.fileExists(atPath: url.path) {
                // 创建目录
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("创建目录失败: \(error.localizedDescription)"))
        }
    }
    
    /// 列出目录内容
    /// - Parameter url: 目录路径
    /// - Returns: 目录内容或错误
    func listDirectory(at url: URL) -> Result<[URL], ConfigForgeError> {
        do {
            // 检查目录是否存在
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.fileAccess("目录不存在: \(url.lastPathComponent)"))
            }
            
            // 获取目录内容
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            
            return .success(contents)
            
        } catch {
            return .failure(.fileAccess("列出目录内容失败: \(error.localizedDescription)"))
        }
    }
} 