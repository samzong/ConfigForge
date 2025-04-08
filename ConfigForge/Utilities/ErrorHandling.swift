import Foundation
import SwiftUI

// 应用错误类型
enum AppError: LocalizedError, Sendable {
    case fileAccess(String)
    case parsing(String)
    case validation(String)
    case network(String)
    case unknown(String)
    
    var errorDescription: String? {
        switch self {
        case .fileAccess(let message): return "文件访问错误: \(message)"
        case .parsing(let message): return "解析错误: \(message)"
        case .validation(let message): return "验证错误: \(message)"
        case .network(let message): return "网络错误: \(message)"
        case .unknown(let message): return "未知错误: \(message)"
        }
    }
}

// 消息类型枚举
enum MessageType: Sendable {
    case error
    case success
    case info
}

// 可识别的消息结构体
struct AppMessage: Identifiable, Sendable {
    let id: UUID
    let type: MessageType
    let message: String
    
    init(id: UUID = UUID(), type: MessageType, message: String) {
        self.id = id
        self.type = type
        self.message = message
    }
}

// 消息处理工具
@MainActor
class MessageHandler: ObservableObject {
    @Published var currentMessage: AppMessage?
    private var messageQueue: [AppMessage] = []
    private var isShowingMessage = false
    
    // 添加一个可以用来发送消息的闭包属性，支持注入消息发送功能
    var messagePoster: (@Sendable (String, MessageType) -> Void)?
    
    func show(_ message: String, type: MessageType = .info, duration: TimeInterval = 1.5) {
        let appMessage = AppMessage(type: type, message: message)
        messageQueue.append(appMessage)
        processMessageQueue()
    }
    
    private func processMessageQueue() {
        guard !isShowingMessage, let message = messageQueue.first else { return }
        
        isShowingMessage = true
        currentMessage = message
        messageQueue.removeFirst()
        
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: UInt64(1.5 * 1_000_000_000))
            withAnimation {
                currentMessage = nil
                isShowingMessage = false
                processMessageQueue()
            }
        }
    }
}

// 错误处理工具
struct ErrorHandler {
    static func handle(_ error: Error, messageHandler: MessageHandler) {
        let message: String
        
        switch error {
        case let appError as AppError:
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

// 视图修饰符：显示消息
struct MessageOverlay: ViewModifier {
    @ObservedObject var messageHandler: MessageHandler
    
    func body(content: Content) -> some View {
        content.overlay(
            Group {
                if let message = messageHandler.currentMessage {
                    VStack {
                        MessageBannerView(message: message)
                        Spacer()
                    }
                    .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
        )
    }
}

// 消息横幅视图
struct MessageBannerView: View {
    let message: AppMessage
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: message.type.iconName)
                .imageScale(.small)
            Text(message.message)
                .font(.caption)
                .lineLimit(1)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(message.type.backgroundColor.opacity(0.9))
        .foregroundColor(.white)
        .cornerRadius(4)
        .shadow(color: Color.black.opacity(0.1), radius: 1, x: 0, y: 1)
        .padding(.horizontal, 10)
        .frame(maxWidth: 300)
        .padding(.top, 2)
    }
}

// 扩展消息类型
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