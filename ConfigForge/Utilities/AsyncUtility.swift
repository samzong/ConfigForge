import Foundation
import SwiftUI

// 通用的异步操作结果类型
enum AsyncOperationResult<T: Sendable>: Sendable {
    case success(T)
    case failure(Error)
}

// 通用的异步操作处理工具
@MainActor
class AsyncUtility: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?
    
    // 执行异步操作的通用方法
    func perform<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T,
                   onStart: (() -> Void)? = nil,
                   onSuccess: ((T) -> Void)? = nil,
                   onError: ((Error) -> Void)? = nil,
                   retryCount: Int = 1) async -> AsyncOperationResult<T> {
        isLoading = true 
        onStart?()
        
        do {
            // 在后台线程执行操作
            let result: T = try await Task.detached(operation: operation).value
            
            isLoading = false
            onSuccess?(result)
            return .success(result)
        } catch {
            isLoading = false
            errorMessage = error.localizedDescription
            onError?(error)
            return .failure(error)
        }
    }
    
    // 带重试的异步操作
    func performWithRetry<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T,
                            retryCount: Int = 3,
                            retryDelay: TimeInterval = 1.0) async -> AsyncOperationResult<T> {
        var currentRetry = 0
        
        while currentRetry <= retryCount {
            do {
                let result = try await operation()
                return .success(result)
            } catch {
                currentRetry += 1
                if currentRetry <= retryCount {
                    try? await Task.sleep(nanoseconds: UInt64(retryDelay * 1_000_000_000))
                    continue
                }
                return .failure(error)
            }
        }
        
        return .failure(NSError(domain: "AsyncUtility", code: -1, userInfo: [NSLocalizedDescriptionKey: "Maximum retry attempts reached"]))
    }
    
    // 防抖动执行异步操作
    func debounce<T: Sendable>(for duration: TimeInterval = 0.5,
                     operation: @escaping @Sendable () async throws -> T) -> () -> Task<AsyncOperationResult<T>, Never> {
        var task: Task<AsyncOperationResult<T>, Never>?
        
        return {
            task?.cancel()
            let newTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                if Task.isCancelled { return AsyncOperationResult<T>.failure(CancellationError()) }
                
                do {
                    let result = try await operation()
                    return AsyncOperationResult<T>.success(result)
                } catch {
                    return AsyncOperationResult<T>.failure(error)
                }
            }
            task = newTask
            return newTask
        }
    }
}

// 视图修饰符：显示加载状态
struct LoadingOverlay: ViewModifier {
    let isLoading: Bool
    
    func body(content: Content) -> some View {
        ZStack {
            content
            if isLoading {
                Color.black.opacity(0.3)
                    .edgesIgnoringSafeArea(.all)
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(1.5)
            }
        }
    }
}

extension View {
    func loadingOverlay(isLoading: Bool) -> some View {
        modifier(LoadingOverlay(isLoading: isLoading))
    }
} 