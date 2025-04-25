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
    
    /// 当前监控的目录和文件
    private var watchedPaths: [String: DispatchSourceFileSystemObject] = [:]
    
    /// 监控队列
    private let watcherQueue = DispatchQueue(label: "com.configforge.filewatcher", attributes: .concurrent)
    
    // MARK: - 监控方法
    
    /// 开始监控指定目录
    /// - Parameters:
    ///   - directoryURL: 要监控的目录 URL
    ///   - fileExtension: 要监控的文件扩展名，如 "yaml"，nil 表示监控所有文件
    /// - Returns: 是否成功开始监控
    @discardableResult
    func watchDirectory(_ directoryURL: URL, fileExtension: String? = nil) -> Bool {
        // 确保是目录
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
              isDirectory.boolValue else {
            print("无法监控 \(directoryURL.path)：不是目录")
            return false
        }
        
        // 设置目录监控
        let directoryPath = directoryURL.path
        setupDirectoryMonitor(directoryPath)
        
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
                _ = watchFile(fileURL)
            }
            
            return true
        } catch {
            print("无法读取目录内容: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 开始监控单个文件
    /// - Parameter fileURL: 要监控的文件 URL
    /// - Returns: 是否成功开始监控
    @discardableResult
    func watchFile(_ fileURL: URL) -> Bool {
        let filePath = fileURL.path
        
        // 确保文件存在且不是目录
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory),
              !isDirectory.boolValue else {
            return false
        }
        
        // 已经在监控此文件
        if watchedPaths[filePath] != nil {
            return true
        }
        
        // 设置文件监控
        setupFileMonitor(filePath)
        return true
    }
    
    /// 停止监控指定路径
    /// - Parameter path: 路径字符串
    func stopWatching(_ path: String) {
        if let source = watchedPaths[path] {
            source.cancel()
            watchedPaths.removeValue(forKey: path)
        }
    }
    
    /// 停止所有监控
    func stopAllWatching() {
        for (path, source) in watchedPaths {
            source.cancel()
            watchedPaths.removeValue(forKey: path)
        }
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
        
        source.setEventHandler { [weak self] in
            let flags = source.data
            let url = URL(fileURLWithPath: path)
            
            if flags.contains(.delete) {
                self?.fileChangesSubject.send(.deleted(url))
                self?.stopWatching(path)
            } else if flags.contains(.rename) {
                self?.fileChangesSubject.send(.directoryChanged(url))
                // 重新扫描目录内容
                self?.rescanDirectory(url)
            } else if flags.contains(.write) || flags.contains(.link) {
                self?.fileChangesSubject.send(.directoryChanged(url))
                // 可能添加了新文件，重新扫描
                self?.rescanDirectory(url)
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        watchedPaths[path] = source
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
        
        source.setEventHandler { [weak self] in
            guard let self = self else { return }
            let flags = source.data
            let url = URL(fileURLWithPath: path)
            
            if flags.contains(.delete) {
                self.fileChangesSubject.send(.deleted(url))
                self.stopWatching(path)
            } else if flags.contains(.rename) {
                // 文件被重命名，我们需要找出新名称
                // 这里简化处理：我们只报告文件被删除
                self.fileChangesSubject.send(.deleted(url))
                self.stopWatching(path)
            } else if flags.contains(.write) || flags.contains(.extend) || flags.contains(.attrib) {
                self.fileChangesSubject.send(.modified(url))
            }
        }
        
        source.setCancelHandler {
            close(fileDescriptor)
        }
        
        source.resume()
        watchedPaths[path] = source
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
                if watchedPaths[filePath] == nil {
                    // 新文件
                    fileChangesSubject.send(.created(fileURL))
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