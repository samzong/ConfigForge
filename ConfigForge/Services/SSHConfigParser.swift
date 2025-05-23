//
//  SSHConfigParser.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation

extension SSHConfigParser: @unchecked Sendable {}

class SSHConfigParser {
    private func isComment(_ line: String) -> Bool {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedLine.hasPrefix("#") || trimmedLine.isEmpty
    }

    private func splitConfigLine(_ line: String) -> (key: String, value: String)? {
        let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedLine.isEmpty || isComment(trimmedLine) {
            return nil
        }
        if let range = trimmedLine.range(of: "\\s+", options: .regularExpression) {
            let key = String(trimmedLine[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmedLine[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            if value.hasPrefix("\"") && value.hasSuffix("\"") && value.count >= 2 {
                value = String(value.dropFirst().dropLast())
            }   
            return (key, value)
        }
        return nil
    }

    func parseConfig(content: String) -> [SSHConfigEntry] {
        var entries = [SSHConfigEntry]()
        var currentHost: String?
        var currentProperties: [String: String] = [:]
        var inMultilineValue = false
        var multilineKey: String?
        var multilineValue: String = ""
        let lines = content.components(separatedBy: .newlines)
        
        for lineIndex in 0..<lines.count {
            let line = lines[lineIndex]
            if line.first?.isWhitespace == true && inMultilineValue && multilineKey != nil {
                multilineValue += " " + line.trimmingCharacters(in: .whitespaces)
                if !line.hasSuffix("\\") {
                    inMultilineValue = false
                    currentProperties[multilineKey!] = multilineValue
                    multilineKey = nil
                    multilineValue = ""
                } else {
                    multilineValue = String(multilineValue.dropLast())
                }
                continue
            }
            let trimmedLine = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmedLine.isEmpty || isComment(trimmedLine) {
                continue
            }
            guard let (key, value) = splitConfigLine(line) else {
                continue
            }
            
            let keyword = key.lowercased()
            if keyword == "host" {
                if let host = currentHost, !host.isEmpty {
                    ensureBasicProperties(properties: &currentProperties)
                    entries.append(SSHConfigEntry(host: host, properties: currentProperties))
                }
                currentHost = value
                currentProperties = [:]
            } else if currentHost != nil {
                let formattedKey = formatPropertyKey(keyword)
                if value.hasSuffix("\\") {
                    inMultilineValue = true
                    multilineKey = formattedKey
                    multilineValue = String(value.dropLast()) 
                } else {
                    currentProperties[formattedKey] = value
                }
            }
        }
        if let host = currentHost, !host.isEmpty {
            ensureBasicProperties(properties: &currentProperties)
            entries.append(SSHConfigEntry(host: host, properties: currentProperties))
        }
        
        return entries
    }

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

    private func formatPropertyKey(_ key: String) -> String {
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
        if let formattedKey = propertyMappings[key.lowercased()] {
            return formattedKey
        }
        return key.prefix(1).uppercased() + key.dropFirst()
    }

    func formatConfig(entries: [SSHConfigEntry]) -> String {
        var content = ""
        
        for entry in entries {
            content += "Host \(entry.host)\n"
            let priorityKeys = AppConstants.commonSSHProperties
            let regularKeys = entry.properties.keys.filter { !priorityKeys.contains($0) }.sorted()
            for key in priorityKeys {
                if let value = entry.properties[key], !value.isEmpty {
                    content += "    \(key) \(formatPropertyValue(value))\n"
                }
            }
            for key in regularKeys {
                if let value = entry.properties[key], !value.isEmpty {
                    content += "    \(key) \(formatPropertyValue(value))\n"
                }
            }
            
            content += "\n"
        }
        
        return content
    }

    func validateEntry(entry: SSHConfigEntry, existingEntries: [SSHConfigEntry]) -> Bool {
        if entry.host.isEmpty {
            return false
        }
        for existingEntry in existingEntries {
            if existingEntry.id != entry.id && existingEntry.host == entry.host {
                return false
            }
        }
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
    
    private func formatPropertyValue(_ value: String) -> String {
        if value.contains(" ") && !value.hasPrefix("\"") && !value.hasSuffix("\"") {
            return "\"\(value)\""
        }
        return value
    }
}
