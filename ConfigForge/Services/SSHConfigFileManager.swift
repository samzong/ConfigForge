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
    private let fileManager: FileManager
    private let sshConfigPath: String
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.sshConfigPath = NSHomeDirectory() + "/.ssh/config"
    }
    
    // 检查文件权限
    private func checkFileAccess() -> Result<Void, ConfigForgeError> {
        let sshDirPath = NSHomeDirectory() + "/.ssh"
        
        // 检查.ssh目录是否存在
        if !fileManager.fileExists(atPath: sshDirPath) {
            do {
                try fileManager.createDirectory(atPath: sshDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return .failure(.fileAccess("无法创建.ssh目录: \(error.localizedDescription)"))
            }
        }
        
        // 检查配置文件是否存在
        if !fileManager.fileExists(atPath: sshConfigPath) {
            do {
                // 创建空的config文件
                try "".write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            } catch {
                return .failure(.fileAccess("无法创建SSH配置文件: \(error.localizedDescription)"))
            }
        }
        
        // 检查文件读写权限
        if !fileManager.isReadableFile(atPath: sshConfigPath) {
            return .failure(.fileAccess("没有SSH配置文件的读取权限"))
        }
        
        if !fileManager.isWritableFile(atPath: sshConfigPath) {
            return .failure(.fileAccess("没有SSH配置文件的写入权限"))
        }
        
        return .success(())
    }
    
    // 读取配置文件
    func readConfigFile() async throws -> String {
        // 先检查文件访问权限
        let accessCheck = checkFileAccess()
        if case .failure(let error) = accessCheck {
            throw error
        }
        
        do {
            let content = try String(contentsOfFile: sshConfigPath, encoding: .utf8)
            return content
        } catch {
            throw ConfigForgeError.configRead("读取SSH配置文件失败: \(error.localizedDescription)")
        }
    }
    
    // 写入配置文件
    func writeConfigFile(content: String) async throws {
        // 先检查文件访问权限
        let accessCheck = checkFileAccess()
        if case .failure(let error) = accessCheck {
            throw error
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
            throw ConfigForgeError.configWrite("写入SSH配置文件失败: \(error.localizedDescription)")
        }
    }
    
    // 备份配置文件
    func backupConfigFile(content: String, to destination: URL) async throws {
        // 写入内容到目标文件
        do {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyyMMdd_HHmmss"
            let timestamp = dateFormatter.string(from: Date())
            
            let backupFileName = "config_backup_\(timestamp)"
            let backupURL = destination.appendingPathComponent(backupFileName)
            
            try content.write(to: backupURL, atomically: true, encoding: .utf8)
        } catch {
            throw ConfigForgeError.configWrite("备份SSH配置文件失败: \(error.localizedDescription)")
        }
    }
    
    // 从备份恢复配置文件
    func restoreConfigFile(from source: URL) async throws -> String {
        do {
            return try String(contentsOf: source, encoding: .utf8)
        } catch {
            throw ConfigForgeError.configRead("从备份恢复SSH配置文件失败: \(error.localizedDescription)")
        }
    }
}
