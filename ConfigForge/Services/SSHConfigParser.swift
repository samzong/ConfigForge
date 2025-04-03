//
//  SSHConfigParser.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

// 使用@unchecked Sendable标记，表明我们手动确保并发安全性
extension SSHConfigParser: @unchecked Sendable {}

class SSHConfigParser {
    // 检查一行是否是注释
    private func isComment(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.hasPrefix("#") || trimmedLine.isEmpty
    }
    
    // 改进的配置行分割逻辑，更好地处理空格和引号
    private func splitConfigLine(_ line: String) -> (key: String, value: String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 忽略空行和注释
        if trimmedLine.isEmpty || isComment(trimmedLine) {
            return nil
        }
        
        // 查找第一个非空格字符后的空格，这将分割关键字和值
        if let range = trimmedLine.range(of: "\\s+", options: .regularExpression) {
            let key = String(trimmedLine[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            
            // 处理引号包围的值
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }
            
            return (key, value)
        }
        
        return nil
    }
    
    // 解析配置文件内容为SSHConfigEntry数组
    func parseConfig(content: String) -> [SSHConfigEntry] {
        var entries = [SSHConfigEntry]()
        var currentHost: String?
        var currentProperties: [String: String] = [:]
        var inMultilineValue = false
        var multilineKey: String?
        var multilineValue: String = ""
        
        // 按行分割配置文件
        let lines = content.components(separatedBy: .newlines)
        
        for lineIndex in 0..<lines.count {
            let line = lines[lineIndex]
            
            // 处理接续行 (以空格或制表符开头的行)
            if line.first?.isWhitespace == true && inMultilineValue && multilineKey != nil {
                multilineValue += " " + line.trimmingCharacters(in: .whitespaces)
                
                // 检查多行值是否结束
                if !line.hasSuffix("\\") {
                    inMultilineValue = false
                    currentProperties[multilineKey!] = multilineValue
                    multilineKey = nil
                    multilineValue = ""
                } else {
                    // 继续累积多行值，移除结尾的反斜杠
                    multilineValue = String(multilineValue.dropLast())
                }
                continue
            }
            
            // 如果不在多行值处理中，正常处理该行
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            
            // 跳过空行和注释行
            if trimmedLine.isEmpty || isComment(trimmedLine) {
                continue
            }
            
            // 使用改进的行拆分逻辑
            guard let (key, value) = splitConfigLine(line) else {
                continue
            }
            
            let keyword = key.lowercased()
            
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
                
                // 处理可能的多行值
                if value.hasSuffix("\\") {
                    inMultilineValue = true
                    multilineKey = formattedKey
                    multilineValue = String(value.dropLast()) // 移除尾部的反斜杠
                } else {
                    // 正常单行值
                    currentProperties[formattedKey] = value
                }
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
        // 使用常量定义的必要属性
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
        // 使用预定义的SSH属性字典进行格式化
        let propertyMappings: [String: String] = [
            "hostname": "HostName",
            "user": "User",
            "port": "Port",
            "identityfile": "IdentityFile",
            "proxycommand": "ProxyCommand",
            "proxyhost": "ProxyHost",
            "proxyport": "ProxyPort",
            "identitiesonly": "IdentitiesOnly",
            "forwardagent": "ForwardAgent",
            "serveraliveinterval": "ServerAliveInterval"
        ]
        
        // 尝试从映射中获取标准格式
        if let formattedKey = propertyMappings[key.lowercased()] {
            return formattedKey
        }
        
        // 如果不是预定义的关键字，首字母大写
        return key.prefix(1).uppercased() + key.dropFirst()
    }
    
    // 将SSHConfigEntry数组格式化为配置文件内容
    func formatConfig(entries: [SSHConfigEntry]) -> String {
        var content = ""
        
        for entry in entries {
            content += "Host \(entry.host)\n"
            
            // 首先排序常用属性
            let priorityKeys = AppConstants.commonSSHProperties
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
        
        // 检查Host是否重复（除了自身）
        for existingEntry in existingEntries {
            if existingEntry.id != entry.id && existingEntry.host == entry.host {
                return false
            }
        }
        
        // 移除对Host特殊字符的限制，SSH配置实际上支持通配符和其他特殊字符
        // 检查端口号是否有效（如果存在）
        if let portStr = entry.properties["Port"], !portStr.isEmpty {
            if let port = Int(portStr) {
                if port < 1 || port > 65535 {
                    return false
                }
            } else {
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
