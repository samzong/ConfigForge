import Foundation

class FileSystemUtils: @unchecked Sendable {
    static let shared = FileSystemUtils()
    private let fileManager: FileManager
    private init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }
    func readFile(at url: URL) -> Result<String, ConfigForgeError> {
        do {
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.fileAccess("文件不存在: \(url.lastPathComponent)"))
            }
            guard isFileReadable(at: url) else {
                return .failure(.fileAccess("无权限读取文件: \(url.lastPathComponent)"))
            }
            let content = try String(contentsOf: url, encoding: .utf8)
            return .success(content)
            
        } catch {
            return .failure(.configRead("读取文件失败: \(error.localizedDescription)"))
        }
    }

    func writeFile(content: String, to url: URL, createBackup: Bool = false) -> Result<Void, ConfigForgeError> {
        do {
            let directory = url.deletingLastPathComponent()
            if !fileManager.fileExists(atPath: directory.path) {
                try fileManager.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
            }
            if createBackup && fileManager.fileExists(atPath: url.path) {
                let backupURL = url.deletingLastPathComponent()
                    .appendingPathComponent(".\(url.lastPathComponent).bak")
                if fileManager.fileExists(atPath: backupURL.path) {
                    try fileManager.removeItem(at: backupURL)
                }
                try fileManager.copyItem(at: url, to: backupURL)
            }
            try content.write(to: url, atomically: true, encoding: .utf8)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            
            return .success(())
            
        } catch {
            return .failure(.configWrite("写入文件失败: \(error.localizedDescription)"))
        }
    }

    func copyFile(from sourceURL: URL, to destinationURL: URL, overwrite: Bool = false) -> Result<Void, ConfigForgeError> {
        do {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                return .failure(.fileAccess("源文件不存在: \(sourceURL.lastPathComponent)"))
            }
            if fileManager.fileExists(atPath: destinationURL.path) {
                if overwrite {
                    try fileManager.removeItem(at: destinationURL)
                } else {
                    return .failure(.fileAccess("目标文件已存在: \(destinationURL.lastPathComponent)"))
                }
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            try fileManager.setAttributes([.posixPermissions: 0o600], ofItemAtPath: destinationURL.path)
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("复制文件失败: \(error.localizedDescription)"))
        }
    }

    func moveFile(from sourceURL: URL, to destinationURL: URL) -> Result<Void, ConfigForgeError> {
        do {
            guard fileManager.fileExists(atPath: sourceURL.path) else {
                return .failure(.fileAccess("源文件不存在: \(sourceURL.lastPathComponent)"))
            }
            if fileManager.fileExists(atPath: destinationURL.path) {
                return .failure(.fileAccess("目标文件已存在: \(destinationURL.lastPathComponent)"))
            }
            try fileManager.moveItem(at: sourceURL, to: destinationURL)
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("移动文件失败: \(error.localizedDescription)"))
        }
    }
    func deleteFile(at url: URL) -> Result<Void, ConfigForgeError> {
        do {
            guard fileManager.fileExists(atPath: url.path) else {
                return .success(()) 
            }
            try fileManager.removeItem(at: url)
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("删除文件失败: \(error.localizedDescription)"))
        }
    }

    func getFileAttributes(at url: URL) -> Result<[FileAttributeKey: Any], ConfigForgeError> {
        do {
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.fileAccess("文件不存在: \(url.lastPathComponent)"))
            }
            let attributes = try fileManager.attributesOfItem(atPath: url.path)
            
            return .success(attributes)
            
        } catch {
            return .failure(.fileAccess("获取文件属性失败: \(error.localizedDescription)"))
        }
    }

    func isFileReadable(at url: URL) -> Bool {
        return fileManager.isReadableFile(atPath: url.path)
    }

    func isFileWritable(at url: URL) -> Bool {
        return fileManager.isWritableFile(atPath: url.path)
    }

    func createDirectoryIfNeeded(at url: URL) -> Result<Void, ConfigForgeError> {
        do {
            if !fileManager.fileExists(atPath: url.path) {
                try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
            
            return .success(())
            
        } catch {
            return .failure(.fileAccess("创建目录失败: \(error.localizedDescription)"))
        }
    }
    
    func listDirectory(at url: URL) -> Result<[URL], ConfigForgeError> {
        do {
            guard fileManager.fileExists(atPath: url.path) else {
                return .failure(.fileAccess("目录不存在: \(url.lastPathComponent)"))
            }
            let contents = try fileManager.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: [])
            
            return .success(contents)
            
        } catch {
            return .failure(.fileAccess("列出目录内容失败: \(error.localizedDescription)"))
        }
    }
} 