import Foundation
import SwiftUI

enum ConfigForgeError: LocalizedError, Sendable {
    case fileAccess(String)
    case configRead(String)
    case configWrite(String)
    case parsing(String)
    case validation(String)
    case network(String)
    case unknown(String)
    case kubeConfigNotFound
    case kubeConfigParsingFailed(String)
    case kubeConfigEncodingFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .fileAccess(let message): return "文件访问错误: \(message)"
        case .configRead(let message): return "配置读取错误: \(message)"
        case .configWrite(let message): return "配置写入错误: \(message)"
        case .parsing(let message): return "解析错误: \(message)"
        case .validation(let message): return "验证错误: \(message)"
        case .network(let message): return "网络错误: \(message)"
        case .unknown(let message): return "未知错误: \(message)"
        case .kubeConfigNotFound: return "Kubeconfig 文件未找到"
        case .kubeConfigParsingFailed(let message): return "Kubeconfig 解析失败: \(message)"
        case .kubeConfigEncodingFailed(let message): return "Kubeconfig 编码失败: \(message)"
        }
    }
}

enum MessageType: Sendable {
    case error
    case success
    case info
}

enum MessagePriority: Sendable {
    case low        // 可省略的成功提示
    case normal     // 一般操作反馈
    case high       // 错误和重要操作
}

struct AppMessage: Identifiable, Sendable {
    let id: UUID
    let type: MessageType
    let message: String
    let priority: MessagePriority
    
    init(id: UUID = UUID(), type: MessageType, message: String, priority: MessagePriority = .normal) {
        self.id = id
        self.type = type
        self.message = message
        self.priority = priority
    }
}

@MainActor
class MessageHandler: ObservableObject {
    @Published var currentMessage: AppMessage?
    private var messageQueue: [AppMessage] = []
    private var isShowingMessage = false

    var messagePoster: (@Sendable (String, MessageType) -> Void)?
    
    func show(_ message: String, type: MessageType = .info, priority: MessagePriority = .normal) {
        if priority == .low {
            return
        }
        
        let appMessage = AppMessage(type: type, message: message, priority: priority)
        messageQueue.append(appMessage)
        processMessageQueue()
    }
    
    private func processMessageQueue() {
        guard !isShowingMessage, let message = messageQueue.first else { return }
        
        isShowingMessage = true
        currentMessage = message
        messageQueue.removeFirst()
        
        let duration = displayDuration(for: message)
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
            withAnimation {
                currentMessage = nil
                isShowingMessage = false
                processMessageQueue()
            }
        }
    }
    
    private func displayDuration(for message: AppMessage) -> TimeInterval {
        switch message.type {
        case .error: return 3.0
        case .success: return 1.0
        case .info: return 2.0
        }
    }
}

struct ErrorHandler {
    static func handle(_ error: Error, messageHandler: MessageHandler) {
        let message: String
        
        switch error {
        case let appError as ConfigForgeError:
            message = appError.localizedDescription
        case let nsError as NSError:
            message = nsError.localizedDescription
        default:
            message = error.localizedDescription
        }
        
        Task { @MainActor in
            messageHandler.show(message, type: .error)
        }
    }
}

struct MessageOverlay: ViewModifier {
    @ObservedObject var messageHandler: MessageHandler
    
    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if let message = messageHandler.currentMessage {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            MessageBannerView(message: message)
                        }
                    }
                    .padding(.bottom, 20)
                    .padding(.trailing, 20)
                    .transition(.move(edge: .trailing).combined(with: .opacity))
                }
            }
        )
    }
}

struct MessageBannerView: View {
    let message: AppMessage
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: message.type.iconName)
                .imageScale(.small)
                .foregroundColor(message.type.backgroundColor)
            Text(message.message)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 8)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(message.type.backgroundColor, lineWidth: 1))
        .foregroundColor(.primary)
        .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
        .frame(maxWidth: 200)
    }
}

extension MessageType {
    var iconName: String {
        switch self {
        case .error: return "xmark.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .info: return "info.circle.fill"
        }
    }
    
    var backgroundColor: Color {
        switch self {
        case .error: return Color(red: 0.9, green: 0.3, blue: 0.3)
        case .success: return Color(red: 0.3, green: 0.7, blue: 0.3)
        case .info: return Color(red: 0.3, green: 0.5, blue: 0.9)
        }
    }
}

extension View {
    func messageOverlay(messageHandler: MessageHandler) -> some View {
        modifier(MessageOverlay(messageHandler: messageHandler))
    }
} 