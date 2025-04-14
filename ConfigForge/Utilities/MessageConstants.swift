import Foundation

// Ensure L10n is accessible (usually via SwiftGen output)
// import Strings // Example if L10n is in a separate module

struct MessageConstants {
    struct SuccessMessages {
        // 使用 SwiftGen 生成的类型安全 API
        static let configLoaded = L10n.Message.Success.Config.loaded
        static let configSaved = L10n.Message.Success.Config.saved
        static let entryAdded = L10n.Message.Success.Entry.added
        static let entryUpdated = L10n.Message.Success.Entry.updated
        static let entryDeleted = L10n.Message.Success.Entry.deleted
        static let configBackedUp = L10n.Message.Success.Config.backup
        static let configRestored = L10n.Message.Success.Config.restore
        static let kubeConfigLoaded = L10n.Kube.configLoaded // 使用自定义扩展
        // Add Kube specific messages if needed
        // static let kubeConfigSaved = L10n.Message.Success.Config.saved
        // static let kubeConfigRestored = L10n.Message.Success.Config.restore
    }

    struct ErrorMessages {
        // 使用 SwiftGen 生成的类型安全 API
        static let fileAccessError = L10n.Message.Error.File.access
        static let configReadError = L10n.CustomError.configReadError // 使用自定义扩展
        static let configWriteError = L10n.CustomError.configWriteError // 使用自定义扩展
        static let parsingError = L10n.CustomError.parsingError // 使用自定义扩展
        static let emptyHostError = L10n.Message.Error.Empty.host
        static let duplicateHostError = L10n.Message.Error.Duplicate.host
        static let backupFailed = L10n.Message.Error.Backup.failed
        static let restoreFailed = L10n.Message.Error.Restore.failed
        static let cannotAccessImportFile = L10n.Error.cannotAccessImportFile
        static let fileImportFailed = L10n.Error.fileImportFailed
        // Add Kube specific errors if needed
    }
} 