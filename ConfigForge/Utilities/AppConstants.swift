import Foundation

struct ConfigForgeConstants {
    static let defaultSSHConfigPath = "~/.ssh/config"
    static let defaultKubeConfigPath = "~/.kube/config"
    
    // Default filenames for backup (base names)
    static let defaultBackupFileName = "ssh_config_backup"
    static let defaultKubeBackupFileName = "kubeconfig_backup"

    struct SuccessMessages {
        static let configLoaded = "success.configLoaded".cfLocalized
        static let configSaved = "success.configSaved".cfLocalized
        static let entryAdded = "success.entryAdded".cfLocalized
        static let entryUpdated = "success.entryUpdated".cfLocalized
        static let entryDeleted = "success.entryDeleted".cfLocalized
        static let configBackedUp = "success.configBackedUp".cfLocalized // Might be shown by system
        static let configRestored = "success.configRestored".cfLocalized
        static let kubeConfigLoaded = "success.kubeConfigLoaded".cfLocalized
        // Add Kube specific messages if needed
        // static let kubeConfigSaved = "success.kubeConfigSaved".cfLocalized 
        // static let kubeConfigRestored = "success.kubeConfigRestored".cfLocalized
    }

    struct ErrorMessages {
        static let fileAccessError = "error.fileAccessError".cfLocalized
        static let configReadError = "error.configReadError".cfLocalized
        static let configWriteError = "error.configWriteError".cfLocalized
        static let parsingError = "error.parsingError".cfLocalized
        static let emptyHostError = "error.emptyHostError".cfLocalized
        static let duplicateHostError = "error.duplicateHostError".cfLocalized
        static let backupFailed = "error.backupFailed".cfLocalized
        static let restoreFailed = "error.restoreFailed".cfLocalized
        static let cannotAccessImportFile = "error.cannotAccessImportFile".cfLocalized
        static let fileImportFailed = "error.fileImportFailed".cfLocalized
         // Add Kube specific errors if needed
    }
} 