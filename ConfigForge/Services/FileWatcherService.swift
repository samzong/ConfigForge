import Foundation
import Combine

enum FileChangeEvent: Equatable {
    case created(URL)
    case modified(URL)
    case deleted(URL)
    case renamed(oldURL: URL, newURL: URL)
    case directoryChanged(URL)
}

class FileWatcherService: @unchecked Sendable {
    private let fileChangesSubject = PassthroughSubject<FileChangeEvent, Never>()
    var fileChanges: AnyPublisher<FileChangeEvent, Never> {
        fileChangesSubject.eraseToAnyPublisher()
    }
    private var watchedPaths = [String: DispatchSourceFileSystemObject]()
    private let watcherQueue = DispatchQueue(label: "com.configforge.filewatcher")
    private let operationQueue = DispatchQueue(label: "com.configforge.filewatcher.operations")

    @discardableResult
    func watchDirectory(_ directoryURL: URL, fileExtension: String? = nil) -> Bool {
        operationQueue.async {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory),
                  isDirectory.boolValue else {
                print("无法监控 \(directoryURL.path)：不是目录")
                return
            }
            let directoryPath = directoryURL.path
            self.setupDirectoryMonitor(directoryPath)
            do {
                let contents = try FileManager.default.contentsOfDirectory(
                    at: directoryURL,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )
                let filesToWatch = fileExtension != nil
                    ? contents.filter { $0.pathExtension.lowercased() == fileExtension!.lowercased() }
                    : contents
                for fileURL in filesToWatch {
                    _ = self.watchFile(fileURL)
                }
            } catch {
                print("无法读取目录内容: \(error.localizedDescription)")
            }
        }
        return true
    }

    @discardableResult
    func watchFile(_ fileURL: URL) -> Bool {
        operationQueue.async {
            let filePath = fileURL.path
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: filePath, isDirectory: &isDirectory),
                  !isDirectory.boolValue else {
                return
            }
            if self.watchedPaths[filePath] != nil {
                return
            }
            self.setupFileMonitor(filePath)
        }
        return true
    }
    func stopWatching(_ path: String) {
        operationQueue.async {
            if let source = self.watchedPaths[path] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
        }
    }

    func stopAllWatching() {
        operationQueue.async {
            let pathsCopy = self.watchedPaths
            for (path, source) in pathsCopy {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
        }
    }

    @discardableResult
    func deleteFile(at url: URL) -> Bool {
        operationQueue.async {
            let path = url.path
            if let source = self.watchedPaths[path] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
            guard FileManager.default.fileExists(atPath: path) else {
                return
            }
            do {
                try FileManager.default.removeItem(at: url)
                self.fileChangesSubject.send(.deleted(url))
            } catch {
                print("删除文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }
    @discardableResult
    func createOrUpdateFile(content: String, at url: URL) -> Bool {
        operationQueue.async {
            let path = url.path
            let fileExists = FileManager.default.fileExists(atPath: path)
            if fileExists, let source = self.watchedPaths[path] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: path)
            }
            do {
                try content.write(to: url, atomically: true, encoding: .utf8)
                if fileExists {
                    self.fileChangesSubject.send(.modified(url))
                } else {
                    self.fileChangesSubject.send(.created(url))
                }
                self.setupFileMonitor(path)
            } catch {
                print("写入文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }

    @discardableResult
    func renameFile(from sourceURL: URL, to destinationURL: URL) -> Bool {
        operationQueue.async {
            let sourcePath = sourceURL.path
            let destinationPath = destinationURL.path
            if let source = self.watchedPaths[sourcePath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: sourcePath)
            }
            if let source = self.watchedPaths[destinationPath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: destinationPath)
            }
            do {
                try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
                self.fileChangesSubject.send(.renamed(oldURL: sourceURL, newURL: destinationURL))
                self.setupFileMonitor(destinationPath)
            } catch {
                print("重命名文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }

    @discardableResult
    func copyFile(from sourceURL: URL, to destinationDirectory: URL, newFileName: String? = nil) -> Bool {
        operationQueue.async {
            let sourcePath = sourceURL.path
            let fileName = newFileName ?? sourceURL.lastPathComponent
            let destinationURL = destinationDirectory.appendingPathComponent(fileName)
            let destinationPath = destinationURL.path
            guard FileManager.default.fileExists(atPath: sourcePath) else {
                print("源文件不存在: \(sourcePath)")
                return
            }
            if FileManager.default.fileExists(atPath: destinationPath) {
                print("目标文件已存在: \(destinationPath)")
                return
            }
            if let source = self.watchedPaths[sourcePath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: sourcePath)
            }
            if let source = self.watchedPaths[destinationPath] {
                source.cancel()
                self.watchedPaths.removeValue(forKey: destinationPath)
            }
            do {
                let content = try String(contentsOf: sourceURL, encoding: .utf8)
                try content.write(to: destinationURL, atomically: true, encoding: .utf8)
                self.fileChangesSubject.send(.created(destinationURL))
                self.setupFileMonitor(destinationPath)
            } catch {
                print("复制文件失败: \(error.localizedDescription)")
            }
        }
        return true
    }
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
            guard let self = self else { return }
            self.operationQueue.async {
                let flags = source.data
                let url = URL(fileURLWithPath: path)
                
                if flags.contains(.delete) {
                    self.fileChangesSubject.send(.deleted(url))
                    self.watchedPaths.removeValue(forKey: path)
                    close(fileDescriptor)
                } else if flags.contains(.rename) {
                    self.fileChangesSubject.send(.directoryChanged(url))
                    self.rescanDirectory(url)
                } else if flags.contains(.write) || flags.contains(.link) {
                    self.fileChangesSubject.send(.directoryChanged(url))
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
            self.operationQueue.async {
                let flags = source.data
                let url = URL(fileURLWithPath: path)
                
                if flags.contains(.delete) {
                    self.fileChangesSubject.send(.deleted(url))
                    self.watchedPaths.removeValue(forKey: path)
                    close(fileDescriptor)
                } else if flags.contains(.rename) {
                    self.fileChangesSubject.send(.deleted(url))
                    self.watchedPaths.removeValue(forKey: path)
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

    private func rescanDirectory(_ directoryURL: URL) {
        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
            
            for fileURL in contents {
                let filePath = fileURL.path
                if self.watchedPaths[filePath] == nil {
                    fileChangesSubject.send(.created(fileURL))
                    _ = watchFile(fileURL)
                }
            }
        } catch {
            print("重新扫描目录失败: \(error.localizedDescription)")
        }
    }
    
    deinit {
        stopAllWatching()
    }
} 