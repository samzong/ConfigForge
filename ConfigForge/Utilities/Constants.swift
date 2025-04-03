//
//  Constants.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

enum AppConstants {
    // SSH配置文件路径
    static let sshConfigPath = NSHomeDirectory() + "/.ssh/config"
    
    // 备份文件默认名称
    static let defaultBackupFileName = "ssh_config_backup"
    
    // 应用名称
    static let appName = "app.name".localized
    
    // 应用版本
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // 错误消息
    enum ErrorMessages {
        static let fileAccessError = "message.error.file.access".localized
        static let invalidConfigFormat = "message.error.invalid.format".localized
        static let duplicateHostError = "message.error.duplicate.host".localized
        static let emptyHostError = "message.error.empty.host".localized
        static let backupFailed = "message.error.backup.failed".localized
        static let restoreFailed = "message.error.restore.failed".localized
        static let invalidPortError = "message.error.invalid.port".localized
        static let permissionDeniedError = "message.error.permission.denied".localized
        static let entryNotFoundError = "message.error.entry.not.found".localized
    }
    
    // 常用的SSH配置属性
    static let commonSSHProperties = [
        "HostName", 
        "User", 
        "Port", 
        "IdentityFile",
        "ProxyCommand",
        "ServerAliveInterval",
        "ForwardAgent",
        "IdentitiesOnly"
    ]
} 