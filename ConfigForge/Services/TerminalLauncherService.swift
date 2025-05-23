import Foundation
import AppKit

struct TerminalApp: Sendable {
    let name: String
    let bundleIdentifier: String
    
    init(name: String, bundleIdentifier: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

actor TerminalLauncherService {
    static let supportedTerminalApps: [TerminalApp] = [
        TerminalApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal"),
        TerminalApp(name: "iTerm", bundleIdentifier: "com.googlecode.iterm2")
    ]
    static let shared = TerminalLauncherService()
    private var permissionRequested = false
    
    private init() {}

    func getInstalledTerminalApps() async -> [TerminalApp] {
        var result: [TerminalApp] = []
        
        for app in Self.supportedTerminalApps {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
            let isInstalled = url != nil
            if !isInstalled && app.bundleIdentifier == "com.apple.Terminal" {
                let standardPaths = [
                    "/System/Applications/Utilities/Terminal.app",
                    "/Applications/Utilities/Terminal.app"
                ]
                
                for path in standardPaths {
                    let fileExists = FileManager.default.fileExists(atPath: path)
                    if fileExists {
                        result.append(app)
                        break
                    }
                }
            } else if isInstalled {
                result.append(app)
            }
        }
        return result
    }

    func launchSSH(host: String, username: String?, port: String?, identityFile: String?, terminal: TerminalApp) async -> Bool {
        var sshCommand = "ssh"
        if let username = username, !username.isEmpty {
            sshCommand += " \(username)@\(host)"
        } else {
            sshCommand += " \(host)"
        }
        if let port = port, !port.isEmpty, port != "22" {
            sshCommand += " -p \(port)"
        }
        if let identityFile = identityFile, !identityFile.isEmpty {
            let expandedPath = (identityFile as NSString).expandingTildeInPath
            let escapedPath = expandedPath.replacingOccurrences(of: " ", with: "\\ ")
            sshCommand += " -i \(escapedPath)"
        }
        
        return await launchTerminalWithCommand(terminal: terminal, command: sshCommand)
    }

    private func launchTerminalWithCommand(terminal: TerminalApp, command: String) async -> Bool {
        let script: String
        switch terminal.bundleIdentifier {
        case "com.apple.Terminal":
            script = """
            tell application "Terminal"
                if not (exists window 1) then
                    do script ""
                end if
                activate
                do script "\(command)" in window 1
            end tell
            """
        case "com.googlecode.iterm2":
            script = """
            tell application "iTerm"
                activate
                if exists current window then
                    tell current window
                        tell current session
                            write text "\(command)"
                        end tell
                    end tell
                else
                    create window with default profile
                    tell current window
                        tell current session
                            write text "\(command)"
                        end tell
                    end tell
                end if
            end tell
            """
        default:
            return false
        }

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&error)
            
            if let error = error {
                if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int, 
                   (errorNumber == -1743 || errorNumber == -1744) {
                    return await executeWithOsascript(script: script)
                }
                return false
            }
            return true
        }
        return await executeWithOsascript(script: script)
    }

    private func executeWithOsascript(script: String) async -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        
        do {
            try process.run()
            process.waitUntilExit()
            return process.terminationStatus == 0
        } catch {
            return false
        }
    }

    func requestAutomationPermission(for terminal: TerminalApp) async {
        if permissionRequested { return }
        let script: String
        switch terminal.bundleIdentifier {
        case "com.apple.Terminal":
            script = """
            tell application "Terminal"
                do script "echo 'ConfigForge testing permission'"
                delay 1
                activate
            end tell
            """
        case "com.googlecode.iterm2":
            script = """
            tell application "iTerm"
                activate
                if exists current window then
                    tell current window
                        tell current session
                            write text "echo 'ConfigForge testing permission'"
                        end tell
                    end tell
                else
                    create window with default profile
                    tell current window
                        tell current session
                            write text "echo 'ConfigForge testing permission'"
                        end tell
                    end tell
                end if
            end tell
            """
        default:
            return
        }

        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&error)
            if error != nil {
                _ = await executeWithOsascript(script: script)
            }
        }
        
        permissionRequested = true
    }
}
