//
//  SSHConfigParser.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

class SSHConfigParser {
    // 解析配置文件内容为SSHConfigEntry数组
    func parseConfig(content: String) -> [SSHConfigEntry] {
        var entries = [SSHConfigEntry]()
        var currentHost: String?
        var currentProperties: [String: String] = [:]
        
        // 按行分割配置文件
        let lines = content.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            if trimmedLine.isEmpty || trimmedLine.hasPrefix("#") {
                continue
            }
            
            // 分割每行为关键字和值
            let components = trimmedLine.components(separatedBy: .whitespaces)
                                       .filter { !$0.isEmpty }
            
            guard components.count >= 2 else { continue }
            
            let keyword = components[0].lowercased()
            let value = components[1...].joined(separator: " ")
            
            // 检查是否是Host行
            if keyword == "host" {
                // 如果已经有当前处理的Host，保存它
                if let host = currentHost, !host.isEmpty {
                    entries.append(SSHConfigEntry(host: host, properties: currentProperties))
                }
                
                // 开始新的Host
                currentHost = value
                currentProperties = [:]
            } else if let host = currentHost {
                // 添加属性到当前Host
                currentProperties[keyword.capitalized] = value
            }
        }
        
        // 处理最后一个Host
        if let host = currentHost, !host.isEmpty {
            entries.append(SSHConfigEntry(host: host, properties: currentProperties))
        }
        
        return entries
    }
    
    // 将SSHConfigEntry数组格式化为配置文件内容
    func formatConfig(entries: [SSHConfigEntry]) -> String {
        var content = ""
        
        for entry in entries {
            content += "Host \(entry.host)\n"
            
            for (key, value) in entry.properties.sorted(by: { $0.key < $1.key }) {
                content += "    \(key) \(value)\n"
            }
            
            content += "\n"
        }
        
        return content
    }
    
    // 验证SSH配置条目是否有效
    func validateEntry(entry: SSHConfigEntry, existingEntries: [SSHConfigEntry]) -> Bool {
        // 检查Host是否为空
        if entry.host.isEmpty {
            return false
        }
        
        // 检查Host是否重复（除了自身）
        for existingEntry in existingEntries {
            if existingEntry.id != entry.id && existingEntry.host == entry.host {
                return false
            }
        }
        
        return true
    }
}
