import Foundation
import Combine

/// 应用程序事件类型
enum AppEvent: Equatable {
    /// 配置文件变更
    case configFileChanged(URL)
    /// 新的配置文件被添加
    case configFileAdded(URL)
    /// 配置文件被删除
    case configFileRemoved(URL)
    /// 活动配置变更
    case activeConfigChanged(KubeConfig?)
    /// 请求重新加载配置
    case reloadConfigRequested
    /// 通知消息
    case notification(String, MessageType)
}

/// 事件管理器，处理应用程序中的事件和通知
@available(macOS 10.15, *)
final class EventManager: @unchecked Sendable {
    // MARK: - 单例实例
    
    /// 共享实例
    static let shared = EventManager()
    
    // MARK: - 事件发布者
    
    /// 事件发布者
    private let eventsSubject = PassthroughSubject<AppEvent, Never>()
    
    /// 事件流（公开为只读）
    var events: AnyPublisher<AppEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }
    
    /// 文件监控服务
    private let fileWatcher = FileWatcherService()
    
    /// KubeConfig 文件管理器
    private let kubeConfigFileManager = KubeConfigFileManager()
    
    /// 取消订阅存储
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - 初始化
    
    /// 私有初始化方法，确保单例模式
    private init() {
        setupFileWatcher()
    }
    
    // MARK: - 设置方法
    
    /// 设置文件监控器
    private func setupFileWatcher() {
        fileWatcher.fileChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fileEvent in
                guard let self = self else { return }
                
                switch fileEvent {
                case .created(let url):
                    // 检查是否是 Kubernetes 配置文件
                    if url.pathExtension.lowercased() == "yaml" || url.pathExtension.lowercased() == "yml" {
                        self.eventsSubject.send(.configFileAdded(url))
                    }
                    
                case .modified(let url):
                    // 检查是否是 Kubernetes 配置文件
                    if url.pathExtension.lowercased() == "yaml" || url.pathExtension.lowercased() == "yml" {
                        self.eventsSubject.send(.configFileChanged(url))
                    }
                    
                case .deleted(let url):
                    // 检查是否是 Kubernetes 配置文件
                    if url.pathExtension.lowercased() == "yaml" || url.pathExtension.lowercased() == "yml" {
                        self.eventsSubject.send(.configFileRemoved(url))
                    }
                    
                case .renamed(oldURL: _, newURL: let newURL):
                    // 检查新文件是否是 Kubernetes 配置文件
                    if newURL.pathExtension.lowercased() == "yaml" || newURL.pathExtension.lowercased() == "yml" {
                        self.eventsSubject.send(.configFileAdded(newURL))
                    }
                    
                case .directoryChanged(let url):
                    // 目录变化，可能需要重新扫描
                    if url.lastPathComponent == "configs" {
                        self.eventsSubject.send(.reloadConfigRequested)
                    }
                }
            }
            .store(in: &cancellables)
    }
    
    // MARK: - 公共方法
    
    /// 开始监控 Kubernetes 配置目录
    /// - Returns: 是否成功开始监控
    @discardableResult
    func startWatchingConfigDirectory() -> Bool {
        do {
            // 创建实例并调用实例方法
            try kubeConfigFileManager.ensureConfigsDirectoryExists()
            
            // 获取配置目录
            if let configDir = try? kubeConfigFileManager.getConfigsDirectoryPath() {
                return fileWatcher.watchDirectory(configDir, fileExtension: "yaml") &&
                       fileWatcher.watchDirectory(configDir, fileExtension: "yml")
            }
            return false
        } catch {
            print("无法确保配置目录存在: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 开始监控主配置文件
    /// - Returns: 是否成功开始监控
    @discardableResult
    func startWatchingMainConfig() -> Bool {
        do {
            // 获取主配置文件路径
            let mainConfigPath = try kubeConfigFileManager.getConfigFilePath()
            return fileWatcher.watchFile(mainConfigPath)
        } catch {
            print("无法获取主配置文件路径: \(error.localizedDescription)")
            return false
        }
    }
    
    /// 发送事件
    /// - Parameter event: 要发送的事件
    func publish(_ event: AppEvent) {
        eventsSubject.send(event)
    }
    
    /// 发送通知事件
    /// - Parameters:
    ///   - message: 通知消息
    ///   - type: 消息类型
    func publishNotification(_ message: String, type: MessageType) {
        eventsSubject.send(.notification(message, type))
    }
    
    /// 请求重新加载配置
    func requestConfigReload() {
        eventsSubject.send(.reloadConfigRequested)
    }
    
    /// 通知活动配置已更改
    /// - Parameter config: 新的活动配置
    func notifyActiveConfigChanged(_ config: KubeConfig?) {
        eventsSubject.send(.activeConfigChanged(config))
    }
} 
