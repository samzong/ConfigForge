import Foundation

struct MessageConstants {
    struct SuccessMessages {
        static let configLoaded = L10n.Message.Success.Config.loaded
        static let configSaved = L10n.Message.Success.Config.saved
        static let entryAdded = L10n.Message.Success.Entry.added
        static let entryUpdated = L10n.Message.Success.Entry.updated
        static let entryDeleted = L10n.Message.Success.Entry.deleted
        static let configBackedUp = L10n.Message.Success.Config.backup
        static let configRestored = L10n.Message.Success.Config.restore
        static let kubeConfigLoaded = L10n.Kube.configLoaded 
    }

    struct ErrorMessages {
        static let fileAccessError = L10n.Message.Error.File.access
        static let configReadError = L10n.CustomError.configReadError 
        static let configWriteError = L10n.CustomError.configWriteError 
        static let parsingError = L10n.CustomError.parsingError 
        static let emptyHostError = L10n.Message.Error.Empty.host
        static let duplicateHostError = L10n.Message.Error.Duplicate.host
        static let backupFailed = L10n.Message.Error.Backup.failed
        static let restoreFailed = L10n.Message.Error.Restore.failed
        static let cannotAccessImportFile = L10n.Error.cannotAccessImportFile
        static let fileImportFailed = L10n.Error.fileImportFailed
    }
} 