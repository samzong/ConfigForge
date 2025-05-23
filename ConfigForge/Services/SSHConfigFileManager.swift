//
//  SSHConfigFileManager.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

extension SSHConfigFileManager: @unchecked Sendable {}

class SSHConfigFileManager {
    private let fileManager: FileManager
    private let sshConfigPath: String
    
    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.sshConfigPath = NSHomeDirectory() + "/.ssh/config"
    }

    private func checkFileAccess() -> Result<Void, ConfigForgeError> {
        let sshDirPath = NSHomeDirectory() + "/.ssh"
        if !fileManager.fileExists(atPath: sshDirPath) {
            do {
                try fileManager.createDirectory(atPath: sshDirPath, withIntermediateDirectories: true, attributes: nil)
            } catch {
                return .failure(.fileAccess("无法创建.ssh目录: \(error.localizedDescription)"))
            }
        }
        if !fileManager.fileExists(atPath: sshConfigPath) {
            do {
                try "".write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            } catch {
                return .failure(.fileAccess("无法创建SSH配置文件: \(error.localizedDescription)"))
            }
        }
        if !fileManager.isReadableFile(atPath: sshConfigPath) {
            return .failure(.fileAccess("没有SSH配置文件的读取权限"))
        }
        
        if !fileManager.isWritableFile(atPath: sshConfigPath) {
            return .failure(.fileAccess("没有SSH配置文件的写入权限"))
        }
        
        return .success(())
    }

    func readConfigFile() async throws -> String {
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

    func writeConfigFile(content: String) async throws {
        let accessCheck = checkFileAccess()
        if case .failure(let error) = accessCheck {
            throw error
        }
        let backupPath = sshConfigPath + ".bak"
        do {
            if fileManager.fileExists(atPath: sshConfigPath) {
                try fileManager.copyItem(atPath: sshConfigPath, toPath: backupPath)
            }
            try content.write(toFile: sshConfigPath, atomically: true, encoding: .utf8)
            if fileManager.fileExists(atPath: backupPath) {
                try fileManager.removeItem(atPath: backupPath)
            }
        } catch {
            if fileManager.fileExists(atPath: backupPath) {
                do {
                    if fileManager.fileExists(atPath: sshConfigPath) {
                        try fileManager.removeItem(atPath: sshConfigPath)
                    }
                    try fileManager.copyItem(atPath: backupPath, toPath: sshConfigPath)
                    try fileManager.removeItem(atPath: backupPath)
                } catch {
                    print("备份恢复失败: \(error)")
                }
            }
            throw ConfigForgeError.configWrite("写入SSH配置文件失败: \(error.localizedDescription)")
        }
    }

    func backupConfigFile(content: String, to destination: URL) async throws {
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
    
    func restoreConfigFile(from source: URL) async throws -> String {
        do {
            return try String(contentsOf: source, encoding: .utf8)
        } catch {
            throw ConfigForgeError.configRead("从备份恢复SSH配置文件失败: \(error.localizedDescription)")
        }
    }
}
