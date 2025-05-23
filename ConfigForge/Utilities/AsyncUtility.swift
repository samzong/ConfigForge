import Foundation
import SwiftUI

enum AsyncOperationResult<T: Sendable>: Sendable {
    case success(T)
    case failure(Error)
}
@MainActor
class AsyncUtility: ObservableObject {
    @Published private(set) var isLoading = false
    @Published var errorMessage: String?

    func perform<T: Sendable>(_ operation: @escaping @Sendable () async throws -> T,
                   onStart: (() -> Void)? = nil,
                   onSuccess: ((T) -> Void)? = nil,
                   onError: ((Error) -> Void)? = nil,
                   retryCount: Int = 1) async -> AsyncOperationResult<T> {
        isLoading = true 
        onStart?()
        
        do {
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
                return .failure(ConfigForgeError.unknown("Maximum retry attempts reached"))
            }
        }
        
        return .failure(ConfigForgeError.unknown("Maximum retry attempts reached"))
    }

    func debounce<T: Sendable>(for duration: TimeInterval = 0.5,
                     operation: @escaping @Sendable () async throws -> T) -> () -> Task<AsyncOperationResult<T>, Never> {
        var task: Task<AsyncOperationResult<T>, Never>?
        
        return {
            task?.cancel()
            let newTask = Task {
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