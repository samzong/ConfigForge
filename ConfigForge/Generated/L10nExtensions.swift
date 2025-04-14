// L10n 扩展 - 为项目中使用的但 SwiftGen 未直接生成的键提供标准访问

import Foundation

// MARK: - 扩展 L10n 以包含缺失的键

extension L10n {
    /// 错误相关的本地化字符串
    public enum CustomError {
        /// 配置读取错误
        public static let configReadError = NSLocalizedString("error.configReadError", comment: "Configuration read error")
        
        /// 配置写入错误
        public static let configWriteError = NSLocalizedString("error.configWriteError", comment: "Configuration write error")
        
        /// 解析错误
        public static let parsingError = NSLocalizedString("error.parsingError", comment: "Parsing error")
    }
    
    /// Kubernetes 相关的本地化字符串
    public enum Kube {
        /// Kubernetes 配置加载成功
        public static let configLoaded = NSLocalizedString("success.kubeConfigLoaded", comment: "Kubernetes configuration loaded successfully")
    }
} 