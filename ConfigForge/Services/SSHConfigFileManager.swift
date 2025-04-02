//
//  SSHConfigFileManager.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

class SSHConfigFileManager {
    private let fileManager = FileManager.default
    
    // 获取SSH配置文件路径
    private var sshConfigPath: String {
        return AppConstants.sshConfigPath
    }
    
    // 读取配置文件
    func readConfigFile() -> Result<String, Error> {
        // 检查文件是否存在，如果不存在则创建一个空文件
        if !fileManager.fileExists(atPath: sshConfigPath) {
            do {
                // 确保.ssh目录存在
                let sshDirPath = NSHomeDirectory() + "/.ssh"
                if !fileManager.fileExists(atPath: sshDirPath) {
                    try fileManager.createDirectory(atPath: sshDirPath, withIntermediateDirectories: true, attributes: nil)
                }
                
                // 创建空的config文件
                try "".write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            } catch {
                return .failure(error)
            }
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
        do {
            try content.write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            return .success(())
        } catch {
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
            // 如果目标文件存在，先删除
            if fileManager.fileExists(atPath: sshConfigPath) {
                try fileManager.removeItem(at: destinationURL)
            }
            
            try fileManager.copyItem(at: source, to: destinationURL)
            return .success(())
        } catch {
            return .failure(error)
        }
    }
}
