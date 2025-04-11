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
    static let appName = "app.name".cfLocalized
    
    // 应用版本
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // 错误消息
    enum ErrorMessages {
        static let fileAccessError = "message.error.file.access".cfLocalized
        static let invalidConfigFormat = "message.error.invalid.format".cfLocalized
        static let duplicateHostError = "message.error.duplicate.host".cfLocalized
        static let emptyHostError = "message.error.empty.host".cfLocalized
        static let backupFailed = "message.error.backup.failed".cfLocalized
        static let restoreFailed = "message.error.restore.failed".cfLocalized
        static let invalidPortError = "message.error.invalid.port".cfLocalized
        static let permissionDeniedError = "message.error.permission.denied".cfLocalized
        static let entryNotFoundError = "message.error.entry.not.found".cfLocalized
    }
    
    // 成功消息
    enum SuccessMessages {
        static let configLoaded = "message.success.config.loaded".cfLocalized
        static let configSaved = "message.success.config.saved".cfLocalized
        static let entryAdded = "message.success.entry.added".cfLocalized
        static let entryUpdated = "message.success.entry.updated".cfLocalized
        static let entryDeleted = "message.success.entry.deleted".cfLocalized
        static let configBackedUp = "message.success.config.backup".cfLocalized
        static let configRestored = "message.success.config.restore".cfLocalized
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