//
//  SSHConfigFileManager.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

// 使用@unchecked Sendable标记，表明我们手动确保并发安全性
extension SSHConfigFileManager: @unchecked Sendable {}

class SSHConfigFileManager {
    private let fileManager = FileManager.default
    
    // 获取SSH配置文件路径
    private var sshConfigPath: String {
        return AppConstants.sshConfigPath
    }
    
    // 检查文件权限
    private func checkFileAccess() -> Result<Void, Error> {
        let sshDirPath = NSHomeDirectory() + "/.ssh"
        
        // 检查.ssh目录是否存在
        if !fileManager.fileExists(atPath: sshDirPath) {
            do {
                try fileManager.createDirectory(atPath: sshDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return .failure(NSError(domain: "com.configforge.error", code: 1, 
                                      userInfo: [NSLocalizedDescriptionKey: "无法创建.ssh目录: \(error.localizedDescription)"]))
            }
        }
        
        // 检查配置文件是否存在
        if !fileManager.fileExists(atPath: sshConfigPath) {
            do {
                // 创建空的config文件
                try "".write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            } catch {
                return .failure(NSError(domain: "com.configforge.error", code: 2, 
                                      userInfo: [NSLocalizedDescriptionKey: "无法创建SSH配置文件: \(error.localizedDescription)"]))
            }
        }
        
        // 检查文件读写权限
        if !fileManager.isReadableFile(atPath: sshConfigPath) {
            return .failure(NSError(domain: "com.configforge.error", code: 3, 
                                   userInfo: [NSLocalizedDescriptionKey: "没有SSH配置文件的读取权限"]))
        }
        
        if !fileManager.isWritableFile(atPath: sshConfigPath) {
            return .failure(NSError(domain: "com.configforge.error", code: 4, 
                                   userInfo: [NSLocalizedDescriptionKey: "没有SSH配置文件的写入权限"]))
        }
        
        return .success(())
    }
    
    // 读取配置文件
    func readConfigFile() -> Result<String, Error> {
        // 先检查文件访问权限
        let accessCheck = checkFileAccess()
        if case .failure(let error) = accessCheck {
            return .failure(error)
        }
        
        do {
            let content = try String(contentsOfFile: sshConfigPath, encoding: .utf8)
            return .success(content)
        } catch {
            return .failure(error)
        }
    }
    
    // 写入配置文件
    func writeConfigFile(content: String) -> Result<Void, Error> {
        // 先检查文件访问权限
        let accessCheck = checkFileAccess()
        if case .failure(let error) = accessCheck {
            return .failure(error)
        }
        
        // 创建临时备份，避免写入中断导致文件损坏
        let backupPath = sshConfigPath + ".bak"
        do {
            // 如果存在原文件，先创建临时备份
            if fileManager.fileExists(atPath: sshConfigPath) {
                try fileManager.copyItem(atPath: sshConfigPath, toPath: backupPath)
            }
            
            // 写入新内容
            try content.write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            
            // 写入成功后删除临时备份
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
            
            return .success(())
        } catch {
            // 写入失败，尝试从备份恢复
            if fileManager.fileExists(atPath: backupPath) {
                do {
                    // 如果目标文件存在，先删除它，然后复制备份
                    if fileManager.fileExists(atPath: sshConfigPath) {
                        try fileManager.removeItem(atPath: sshConfigPath)
                    }
                    try fileManager.copyItem(atPath: backupPath, toPath: sshConfigPath)
                    try fileManager.removeItem(atPath: backupPath)
                } catch {
                    // 恢复失败，记录但不抛出异常
                    print("备份恢复失败: \(error)")
                }
            }
            return .failure(error)
        }
    }
    
    // 备份配置文件
    func backupConfigFile(to destination: URL) -> Result<URL, Error> {
        let sourceURL = URL(fileURLWithPath: sshConfigPath)
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        
        let backupFileName = "config_backup_\(timestamp)"
        let backupURL = destination.appendingPathComponent(backupFileName)
        
        do {
            try fileManager.copyItem(at: sourceURL, to: backupURL)
            return .success(backupURL)
        } catch {
            return .failure(error)
        }
    }
    
    // 从备份恢复配置文件
    func restoreConfigFile(from source: URL) -> Result<Void, Error> {
        let destinationURL = URL(fileURLWithPath: sshConfigPath)
        
        do {
            // 尝试创建原文件的备份，以防恢复失败
            let backupPath = sshConfigPath + ".restore_bak"
            if fileManager.fileExists(atPath: sshConfigPath) {
                try fileManager.copyItem(atPath: sshConfigPath, toPath: backupPath)
            }
            
            // 如果目标文件存在，先删除
            if fileManager.fileExists(atPath: sshConfigPath) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: source, to: destinationURL)
            
            // 恢复成功，删除临时备份
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
            
            return .success(())
        } catch {
            // 恢复失败，尝试从临时备份恢复
            let backupPath = sshConfigPath + ".restore_bak"
            if fileManager.fileExists(atPath: backupPath) {
                do {
                    // 如果目标文件存在，先删除它，然后复制备份
                    if fileManager.fileExists(atPath: sshConfigPath) {
                        try fileManager.removeItem(atPath: sshConfigPath)
                    }
                    try fileManager.copyItem(atPath: backupPath, toPath: sshConfigPath)
                    try fileManager.removeItem(atPath: backupPath)
                } catch {
                    print("恢复备份失败: \(error)")
                }
            }
            return .failure(error)
        }
    }
}
