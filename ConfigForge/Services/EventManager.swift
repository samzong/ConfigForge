import Foundation
import Combine

enum AppEvent: Equatable {
    case configFileChanged(URL)
    case configFileAdded(URL)
    case configFileRemoved(URL)
    case activeConfigChanged(String)
    case reloadConfigRequested
    case notification(String, MessageType)
}

@available(macOS 10.15, *)
final class EventManager: @unchecked Sendable {
    static let shared = EventManager()
    private let eventsSubject = PassthroughSubject<AppEvent, Never>()
    var events: AnyPublisher<AppEvent, Never> {
        eventsSubject.eraseToAnyPublisher()
    }
    private let fileWatcher = FileWatcherService()
    private let kubeConfigFileManager = KubeConfigFileManager()
    private var cancellables = Set<AnyCancellable>()
    private init() {
        setupFileWatcher()
    }

    private func setupFileWatcher() {
        fileWatcher.fileChanges
            .receive(on: DispatchQueue.main)
            .sink { [weak self] fileEvent in
                guard let self = self else { return }

                switch fileEvent {
                case .created(let url):
                    if url.pathExtension.lowercased() == "yaml" || url.pathExtension.lowercased() == "yml" {
                        eventsSubject.send(.configFileAdded(url))
                    }

                case .modified(let url):
                    if url.pathExtension.lowercased() == "yaml" || url.pathExtension.lowercased() == "yml" {
                        eventsSubject.send(.configFileChanged(url))
                    }

                case .deleted(let url):
                    if url.pathExtension.lowercased() == "yaml" || url.pathExtension.lowercased() == "yml" {
                        eventsSubject.send(.configFileRemoved(url))
                    }

                case .renamed(oldURL: _, newURL: let newURL):
                    if newURL.pathExtension.lowercased() == "yaml" || newURL.pathExtension.lowercased() == "yml" {
                        eventsSubject.send(.configFileAdded(newURL))
                    }

                case .directoryChanged(let url):
                    if url.lastPathComponent == "configs" {
                        eventsSubject.send(.reloadConfigRequested)
                    }
                }
            }
            .store(in: &cancellables)
    }

    @discardableResult
    func startWatchingConfigDirectory() -> Bool {
        do {
            try kubeConfigFileManager.ensureConfigsDirectoryExists()
            if let configDir = try? kubeConfigFileManager.getConfigsDirectoryPath() {
                return fileWatcher.watchDirectory(configDir, fileExtension: "yaml") &&
                    fileWatcher.watchDirectory(configDir, fileExtension: "yml")
            }
            return false
        } catch {
            print("Cannot guarantee the existence of the configuration directory.: \(error.localizedDescription)")
            return false
        }
    }
    @discardableResult
    func startWatchingMainConfig() -> Bool {
        do {
            let mainConfigPath = try kubeConfigFileManager.getConfigFilePath()
            return fileWatcher.watchFile(mainConfigPath)
        } catch {
            print("Cannot obtain the path of the main configuration file: \(error.localizedDescription)")
            return false
        }
    }
    @discardableResult
    func stopAllFileWatching() -> Bool {
        fileWatcher.stopAllWatching()
        return true
    }
    func publish(_ event: AppEvent) {
        eventsSubject.send(event)
    }
    func publishNotification(_ message: String, type: MessageType) {
        eventsSubject.send(.notification(message, type))
    }
    func requestConfigReload() {
        eventsSubject.send(.reloadConfigRequested)
    }
    func notifyActiveConfigChanged(_ yamlContent: String) {
        eventsSubject.send(.activeConfigChanged(yamlContent))
    }
    func getFileWatcher() -> FileWatcherService {
        return fileWatcher
    }
} 
