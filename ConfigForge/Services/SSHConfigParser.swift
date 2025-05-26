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
        var currentDirectives: [(key: String, value: String)] = []
        var inMultilineValue = false
        var multilineKey: String?
        let lines = content.components(separatedBy: .newlines)

        for lineIndex in 0..<lines.count {
            let line = lines[lineIndex]
            if line.first?.isWhitespace == true && inMultilineValue && multilineKey != nil {
                if var lastDirective = currentDirectives.popLast(), lastDirective.key == multilineKey {
                    var lineContent = line.trimmingCharacters(in: .whitespaces)
                    if lineContent.hasSuffix("\\") {
                        lineContent = String(lineContent.dropLast())
                        lastDirective.value += " " + lineContent
                        currentDirectives.append(lastDirective)
                    } else {
                        lastDirective.value += " " + lineContent
                        currentDirectives.append(lastDirective)
                        inMultilineValue = false
                        multilineKey = nil
                    }
                } else {
                    // This case should ideally not happen if logic is correct
                    // Or, if the first part of a multiline was not added, which is a bug
                    // For now, let's add the previous directive back if it was popped
                    if let poppedDirective = currentDirectives.popLast(), poppedDirective.key == multilineKey {
                        currentDirectives.append(poppedDirective) // Add it back
                    }
                    // And ignore this continuation line or log an error
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
                    // ensureBasicProperties call removed
                    entries.append(SSHConfigEntry(host: host, directives: currentDirectives))
                }
                currentHost = value
                currentDirectives = []
            } else if currentHost != nil {
                let formattedKey = formatPropertyKey(keyword)
                if value.hasSuffix("\\") {
                    inMultilineValue = true
                    multilineKey = formattedKey
                    currentDirectives.append((key: formattedKey, value: String(value.dropLast())))
                } else {
                    currentDirectives.append((key: formattedKey, value: value))
                }
            }
        }
        if let host = currentHost, !host.isEmpty {
            // ensureBasicProperties call removed
            entries.append(SSHConfigEntry(host: host, directives: currentDirectives))
        }

        return entries
    }

    // ensureBasicProperties method removed

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
            for directive in entry.directives {
                if !directive.value.isEmpty { // Optionally skip empty values, or handle as needed
                    content += "    \(directive.key) \(formatPropertyValue(directive.value))\n"
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
                return false // Duplicate host
            }
        }
        // Use the computed property isPortValid from SSHConfigEntry, which already handles directives
        // and provides default port "22" logic.
        // If port is explicitly set and invalid, isPortValid will be false.
        // If port is not set, isPortValid is true (as "22" is valid).
        // So, we only need to check if it's NOT valid.
        if !entry.isPortValid {
            return false
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
