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
    static let appName = L10n.App.name
    
    // 应用版本
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // 错误消息
    enum ErrorMessages {
        static let fileAccessError = L10n.Message.Error.File.access
        static let invalidConfigFormat = L10n.Message.Error.Invalid.format
        static let duplicateHostError = L10n.Message.Error.Duplicate.host
        static let emptyHostError = L10n.Message.Error.Empty.host
        static let backupFailed = L10n.Message.Error.Backup.failed
        static let restoreFailed = L10n.Message.Error.Restore.failed
        static let invalidPortError = L10n.Message.Error.Invalid.port
        static let permissionDeniedError = L10n.Message.Error.Permission.denied
        static let entryNotFoundError = L10n.Message.Error.Entry.Not.found
    }
    
    // 成功消息
    enum SuccessMessages {
        static let configLoaded = L10n.Message.Success.Config.loaded
        static let configSaved = L10n.Message.Success.Config.saved
        static let entryAdded = L10n.Message.Success.Entry.added
        static let entryUpdated = L10n.Message.Success.Entry.updated
        static let entryDeleted = L10n.Message.Success.Entry.deleted
        static let configBackedUp = L10n.Message.Success.Config.backup
        static let configRestored = L10n.Message.Success.Config.restore
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
