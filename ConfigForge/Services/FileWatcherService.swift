import Foundation
import Combine

/// 文件变更事件类型
enum FileChangeEvent: Equatable {
    /// 文件被创建
    case created(URL)
    /// 文件被修改
    case modified(URL)
    /// 文件被删除
    case deleted(URL)
    /// 文件被重命名
    case renamed(oldURL: URL, newURL: URL)
    /// 目录内容变化
    case directoryChanged(URL)
}

/// 文件监控服务，用于监视文件系统变化并通知订阅者
class FileWatcherService {
    // MARK: - 属性
    
    /// 文件变化事件发布者
    private let fileChangesSubject = PassthroughSubject<FileChangeEvent, Never>()
    
    /// 文件变化事件发布者（公开为只读）
    var fileChanges: AnyPublisher<FileChangeEvent, Never> {
        fileChangesSubject.eraseToAnyPublisher()
    }
    
    /// 当前监控的目录和文件 - 使用串行队列保护访问
    private var watchedPaths = [String: DispatchSourceFileSystemObject]()
    
    /// 监控队列 - 使用串行队列避免竞争条件
    private let watcherQueue = DispatchQueue(label: "com.configforge.filewatcher")
    
    /// 操作队列 - 用于同步文件操作
    private let operationQueue = DispatchQueue(label: "com.configforge.filewatcher.operations")
    
    // MARK: - 监控方法
    
    /// 开始监控指定目录
    /// - Parameters:
    ///   - directoryURL: 要监控的目录 URL
    ///   - fileExtension: 要监控的文件扩展名，如 "yaml"，nil 表示监控所有文件
    /// - Returns: 是否成功开始监控
    @discardableResult
    func watchDirectory(_ directoryURL: URL, fileExtension: String? = nil) -> Bool {
        operationQueue.async {
            // 确保是目录
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                print("无法监控 \(directoryURL.path)：不是目录")
                return
            }
            
            // 设置目录监控
            let directoryPath = directoryURL.path
            self.setupDirectoryMonitor(directoryPath)
            
            // 监控目录内的现有文件
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                
                // 过滤指定扩展名的文件（如果提供了扩展名）
                let filesToWatch = fileExtension != nil
                    ? contents.filter { $0.pathExtension.lowercased() == fileExtension!.lowercased() }
                    : contents
                
                // 为每个文件设置监控
                for fileURL in filesToWatch {
                    _ = self.watchFile(fileURL)
                }
            } catch {
                print("无法读取目录内容: \(error.localizedDescription)")
            }
        }
        return true
    }
    
    /// 开始监控单个文件
    /// - Parameter fileURL: 要监控的文件 URL
    /// - Returns: 是否成功开始监控
    @discardableResult
    func watchFile(_ fileURL: URL) -> Bool {
        operationQueue.async {
            let filePath = fileURL.path
            
            // 确保文件存在且不是目录
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                return
            }
            
            // 已经在监控此文件，避免重复设置
            if self.watchedPaths[filePath] != nil {
                return
            }
            
            // 设置文件监控
            self.setupFileMonitor(filePath)
        }
        return true
    }
    
    /// 停止监控指定路径
    /// - Parameter path: 路径字符串
    func stopWatching(_ path: String) {
        operationQueue.async {
            if let source = self.watchedPaths[path] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
        }
    }
    
    /// 停止所有监控
    func stopAllWatching() {
        operationQueue.async {
            let pathsCopy = self.watchedPaths
            for (path, source) in pathsCopy {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
        }
    }
    
    // MARK: - 统一文件操作 API
    
    /// 删除文件并处理相关监控
    /// - Parameter url: 要删除的文件 URL
    /// - Returns: 操作是否成功
    @discardableResult
    func deleteFile(at url: URL) -> Bool {
        operationQueue.async {
            let path = url.path
            
            // 1. 先停止监控并释放资源
            if let source = self.watchedPaths[path] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
            
            // 2. 如果文件不存在，返回成功
            guard FileManager.default.fileExists(atPath: path) else {
                return
            }
            
            // 3. 删除文件
            do {
                try FileManager.default.removeItem(at: url)
                // 4. 发送删除事件通知
                self.fileChangesSubject.send(.deleted(url))
            } catch {
                print("删除文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }
    
    /// 创建或更新文件并处理相关监控
    /// - Parameters:
    ///   - content: 文件内容
    ///   - url: 文件URL
    /// - Returns: 操作是否成功
    @discardableResult
    func createOrUpdateFile(content: String, at url: URL) -> Bool {
        operationQueue.async {
            let path = url.path
            let fileExists = FileManager.default.fileExists(atPath: path)
            
            // 1. 如果文件已存在且正在监控，先停止监控
            if fileExists, let source = self.watchedPaths[path] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
            
            // 2. 写入文件内容
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                
                // 3. 发送适当的事件
                if fileExists {
                    self.fileChangesSubject.send(.modified(url))
                } else {
                    self.fileChangesSubject.send(.created(url))
                }
                
                // 4. 重新设置文件监控
                self.setupFileMonitor(path)
            } catch {
                print("写入文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }
    
    /// 重命名文件并处理相关监控
    /// - Parameters:
    ///   - sourceURL: 源文件 URL
    ///   - destinationURL: 目标文件 URL
    /// - Returns: 操作是否成功
    @discardableResult
    func renameFile(from sourceURL: URL, to destinationURL: URL) -> Bool {
        operationQueue.async {
            let sourcePath = sourceURL.path
            let destinationPath = destinationURL.path
            
            // 1. 如果源文件正在监控，先停止监控
            if let source = self.watchedPaths[sourcePath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: sourcePath)
            }
            
            // 2. 如果目标文件正在监控，也停止监控
            if let source = self.watchedPaths[destinationPath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: destinationPath)
            }
            
            // 3. 重命名文件
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                
                // 4. 发送重命名事件
                self.fileChangesSubject.send(.renamed(oldURL: sourceURL, newURL: destinationURL))
                
                // 5. 设置对新文件的监控
                self.setupFileMonitor(destinationPath)
            } catch {
                print("重命名文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }
    
    /// 复制文件并处理相关监控
    /// - Parameters:
    ///   - sourceURL: 源文件 URL
    ///   - destinationDirectory: 目标目录 URL
    ///   - newFileName: 新的文件名 (可选，如果不提供则使用原始文件名)
    /// - Returns: 操作是否成功
    @discardableResult
    func copyFile(from sourceURL: URL, to destinationDirectory: URL, newFileName: String? = nil) -> Bool {
        operationQueue.async {
            let sourcePath = sourceURL.path
            
            // 确定目标文件名
            let fileName = newFileName ?? sourceURL.lastPathComponent
            let destinationURL = destinationDirectory.appendingPathComponent(fileName)
            let destinationPath = destinationURL.path
            
            // 检查源文件是否存在
            guard FileManager.default.fileExists(atPath: sourcePath) else {
                print("源文件不存在: \(sourcePath)")
                return
            }
            
            // 检查目标文件是否已存在
            if FileManager.default.fileExists(atPath: destinationPath) {
                print("目标文件已存在: \(destinationPath)")
                return
            }
            
            // 1. 停止对源文件的监控（如果有）
            if let source = self.watchedPaths[sourcePath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: sourcePath)
            }
            
            // 2. 停止对目标文件的监控（如果有）
            if let source = self.watchedPaths[destinationPath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: destinationPath)
            }
            
            // 3. 执行复制操作
            do {
                // 读取源文件内容
                let content = try String(contentsOf: sourceURL, encoding: .utf8)
                
                // 写入目标文件
                try content.write(to: destinationURL, atomically: true, encoding: .utf8)
                
                // 4. 发送创建事件
                self.fileChangesSubject.send(.created(destinationURL))
                
                // 5. 重新设置监控
                self.setupFileMonitor(destinationPath)
            } catch {
                print("复制文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }
    
    // MARK: - 私有辅助方法
    
    /// 设置目录监控
    private func setupDirectoryMonitor(_ path: String) {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("无法为目录 \(path) 创建文件描述符")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .link],
            queue: watcherQueue
        )
        
        // 使用弱引用避免循环引用
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // 在操作队列中处理事件，确保线程安全
            self.operationQueue.async {
                let flags = source.data
                let url = URL(fileURLWithPath: path)
                
                if flags.contains(.delete) {
                    self.fileChangesSubject.send(.deleted(url))
                    // 从路径字典中移除
                    self.watchedPaths.removeValue(forKey: path)
                    // 关闭文件描述符
                    close(fileDescriptor)
                } else if flags.contains(.rename) {
                    self.fileChangesSubject.send(.directoryChanged(url))
                    // 重新扫描目录内容
                    self.rescanDirectory(url)
                } else if flags.contains(.write) || flags.contains(.link) {
                    self.fileChangesSubject.send(.directoryChanged(url))
                    // 可能添加了新文件，重新扫描
                    self.rescanDirectory(url)
                }
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        self.watchedPaths[path] = source
    }
    
    /// 设置文件监控
    private func setupFileMonitor(_ path: String) {
        let fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor >= 0 else {
            print("无法为文件 \(path) 创建文件描述符")
            return
        }
        
        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: [.write, .rename, .delete, .extend, .attrib],
            queue: watcherQueue
        )
        
        // 使用弱引用避免循环引用
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            
            // 在操作队列中处理事件，确保线程安全
            self.operationQueue.async {
                let flags = source.data
                let url = URL(fileURLWithPath: path)
                
                if flags.contains(.delete) {
                    self.fileChangesSubject.send(.deleted(url))
                    // 从路径字典中移除
                    self.watchedPaths.removeValue(forKey: path)
                    // 关闭文件描述符
                    close(fileDescriptor)
                } else if flags.contains(.rename) {
                    // 文件被重命名，简化处理为删除
                    self.fileChangesSubject.send(.deleted(url))
                    // 从路径字典中移除
                    self.watchedPaths.removeValue(forKey: path)
                    // 关闭文件描述符
                    close(fileDescriptor)
                } else if flags.contains(.write) || flags.contains(.extend) || flags.contains(.attrib) {
                    self.fileChangesSubject.send(.modified(url))
                }
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        self.watchedPaths[path] = source
    }
    
    /// 重新扫描目录以检测新文件
    private func rescanDirectory(_ directoryURL: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for fileURL in contents {
                let filePath = fileURL.path
                // 线程安全地检查文件是否已监控
                if self.watchedPaths[filePath] == nil {
                    // 新文件
                    fileChangesSubject.send(.created(fileURL))
                    // 设置监控
                    _ = watchFile(fileURL)
                }
            }
        } catch {
            print("重新扫描目录失败: \(error.localizedDescription)")
        }
    }
    
    // MARK: - 初始化和销毁
    
    deinit {
        stopAllWatching()
    }
} 