import SwiftUI
import Foundation

// MARK: - SwiftUI Text 扩展

extension Text {
    /// 使用类型安全的 L10n 本地化键创建文本
    /// - Parameter key: L10n 类型的本地化键
    /// - Returns: 本地化的文本视图
    static func localized(_ key: String) -> Text {
        return Text(key)
    }
}

// MARK: - 便于迁移的 String 扩展

extension String {
    /// 将被废弃，请使用 SwiftGen 生成的 L10n 类型
    @available(*, deprecated, message: "请使用 SwiftGen 生成的 L10n 类型，例如 L10n.App.save")
    var cfLocalized: String {
        return self
    }
    
    /// 将被废弃，请使用 SwiftGen 生成的 L10n 类型
    @available(*, deprecated, message: "请使用 SwiftGen 生成的 L10n 类型，例如 L10n.Kubernetes.Cluster.edit(clusterName)")
    func cfLocalized(with arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, bundle: .main, comment: "")
        return String(format: format, arguments: arguments)
    }
}

// MARK: - 便捷的本地化视图

/// 使用 L10n 类型的本地化文本视图
struct L10nText: View {
    let key: LocalizedStringKey
    
    init(_ key: String) {
        self.key = LocalizedStringKey(key)
    }
    
    var body: some View {
        Text(key)
    }
} 