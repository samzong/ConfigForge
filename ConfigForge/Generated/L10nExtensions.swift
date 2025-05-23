
import Foundation

extension L10n {
    public enum CustomError {
        public static let configReadError = NSLocalizedString("error.configReadError", comment: "Configuration read error")
        public static let configWriteError = NSLocalizedString("error.configWriteError", comment: "Configuration write error")
        public static let parsingError = NSLocalizedString("error.parsingError", comment: "Parsing error")
    }
    public enum Kube {
        public static let configLoaded = NSLocalizedString("success.kubeConfigLoaded", comment: "Kubernetes configuration loaded successfully")
    }
} 