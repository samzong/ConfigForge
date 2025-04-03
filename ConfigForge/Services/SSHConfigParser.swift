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
            let components = trimmedLine.split(maxSplits: 1, whereSeparator: { $0.isWhitespace })
                                       .map(String.init)
            
            guard components.count >= 2 else { continue }
            
            let keyword = components[0].lowercased()
            let value = components[1].trimmingCharacters(in: .whitespaces)
            
            // 检查是否是Host行
            if keyword == "host" {
                // 如果已经有当前处理的Host，保存它
                if let host = currentHost, !host.isEmpty {
                    // 确保基本属性存在
                    ensureBasicProperties(properties: &currentProperties)
                    entries.append(SSHConfigEntry(host: host, properties: currentProperties))
                }
                
                // 开始新的Host
                currentHost = value
                currentProperties = [:]
            } else if currentHost != nil {
                // 添加属性到当前Host，确保HostName等属性名称大小写正确
                let formattedKey = formatPropertyKey(keyword)
                currentProperties[formattedKey] = value
            }
        }
        
        // 处理最后一个Host
        if let host = currentHost, !host.isEmpty {
            // 确保基本属性存在
            ensureBasicProperties(properties: &currentProperties)
            entries.append(SSHConfigEntry(host: host, properties: currentProperties))
        }
        
        return entries
    }
    
    // 确保基本属性存在
    private func ensureBasicProperties(properties: inout [String: String]) {
        if !properties.keys.contains("HostName") {
            properties["HostName"] = ""
        }
        
        if !properties.keys.contains("User") {
            properties["User"] = ""
        }
        
        if !properties.keys.contains("Port") {
            properties["Port"] = "22"
        }
        
        if !properties.keys.contains("IdentityFile") {
            properties["IdentityFile"] = ""
        }
    }
    
    // 标准化属性名称
    private func formatPropertyKey(_ key: String) -> String {
        switch key.lowercased() {
        case "hostname": return "HostName"
        case "user": return "User"
        case "port": return "Port"
        case "identityfile": return "IdentityFile"
        default:
            // 其他属性首字母大写
            return key.prefix(1).uppercased() + key.dropFirst()
        }
    }
    
    // 将SSHConfigEntry数组格式化为配置文件内容
    func formatConfig(entries: [SSHConfigEntry]) -> String {
        var content = ""
        
        for entry in entries {
            content += "Host \(entry.host)\n"
            
            // 首先排序常用属性
            let priorityKeys = ["HostName", "User", "Port", "IdentityFile"]
            let regularKeys = entry.properties.keys.filter { !priorityKeys.contains($0) }.sorted()
            
            // 添加常用属性 - 只添加有值的属性
            for key in priorityKeys {
                if let value = entry.properties[key], !value.isEmpty {
                    content += "    \(key) \(formatPropertyValue(value))\n"
                }
            }
            
            // 添加其他属性 - 只添加有值的属性
            for key in regularKeys {
                if let value = entry.properties[key], !value.isEmpty {
                    content += "    \(key) \(formatPropertyValue(value))\n"
                }
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
        
        // 检查Host是否包含空格或特殊字符
        let allowedCharacters = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_.*?"))
        if entry.host.rangeOfCharacter(from: allowedCharacters.inverted) != nil {
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
    
    // 格式化属性值（处理包含空格的属性值）
    private func formatPropertyValue(_ value: String) -> String {
        if value.contains(" ") && !value.hasPrefix("\"") && !value.hasSuffix("\"") {
            return "\"\(value)\""
        }
        return value
    }
}
