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
    static let appName = "ConfigForge"
    
    // 应用版本
    static var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }
    
    // 错误消息
    enum ErrorMessages {
        static let fileAccessError = "无法访问SSH配置文件。请确保应用有权限访问您的.ssh目录。"
        static let invalidConfigFormat = "配置文件格式无效。某些条目可能无法正确解析。"
        static let duplicateHostError = "主机名已存在，请使用不同的名称。"
        static let emptyHostError = "主机名不能为空。"
        static let backupFailed = "备份失败，请检查文件权限。"
        static let restoreFailed = "恢复失败，备份文件可能已损坏。"
    }
} 