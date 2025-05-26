import SwiftUI
import Foundation

extension Text {
    static func localized(_ key: String) -> Text {
        return Text(key)
    }
}

extension String {
    @available(*, deprecated, message: "请使用 SwiftGen 生成的 L10n 类型，例如 L10n.App.save")
    var cfLocalized: String {
        return self
    }
    @available(*, deprecated, message: "请使用 SwiftGen 生成的 L10n 类型，例如 L10n.Kubernetes.Cluster.edit(clusterName)")
    func cfLocalized(with arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, bundle: .main, comment: "")
        return String(format: format, arguments: arguments)
    }
}

struct L10nText: View {
    let key: LocalizedStringKey

    init(_ key: String) {
        self.key = LocalizedStringKey(key)
    }

    var body: some View {
        Text(key)
    }
} 