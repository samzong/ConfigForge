import Foundation
import AppKit
import Carbon.HIToolbox

// MARK: - Apple Event constants and helpers
let kASAppleScriptSuite: AEEventClass = 0x61736372 // 'ascr'
let kASGetPropertyEvent: AEEventID = 0x67657470 // 'getp'
let kAnyTransaction: AETransactionID = 0

// Helper functions for Apple Events
extension NSAppleEventDescriptor {
    static func createAutomationEvent(
        for app: NSRunningApplication,
        eventClass: AEEventClass,
        eventID: AEEventID
    ) -> NSAppleEventDescriptor {
        let target = NSAppleEventDescriptor(processIdentifier: app.processIdentifier)
        return NSAppleEventDescriptor(
            eventClass: eventClass,
            eventID: eventID,
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransaction)
        )
    }
    
    static func createBundleEvent(
        bundleIdentifier: String,
        eventClass: AEEventClass,
        eventID: AEEventID
    ) -> NSAppleEventDescriptor {
        let target = NSAppleEventDescriptor(bundleIdentifier: bundleIdentifier)
        return NSAppleEventDescriptor(
            eventClass: eventClass,
            eventID: eventID,
            targetDescriptor: target,
            returnID: AEReturnID(kAutoGenerateReturnID),
            transactionID: AETransactionID(kAnyTransaction)
        )
    }
}

struct TerminalApp: Sendable {
    let name: String
    let bundleIdentifier: String
    
    init(name: String, bundleIdentifier: String) {
        self.name = name
        self.bundleIdentifier = bundleIdentifier
    }
}

actor TerminalLauncherService {
    // Available terminal apps
    static let supportedTerminalApps: [TerminalApp] = [
        TerminalApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal"),
        TerminalApp(name: "iTerm", bundleIdentifier: "com.googlecode.iterm2")
    ]
    
    // Singleton instance for shared access
    static let shared = TerminalLauncherService()
    
    private init() {
        // 在初始化时触发权限检查 (移除引用)
    }
    
    // Get installed terminal apps
    func getInstalledTerminalApps() async -> [TerminalApp] {
        var result: [TerminalApp] = []
        
        for app in Self.supportedTerminalApps {
            // Check using standard NSWorkspace method first
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
            let isInstalled = url != nil
            
            // Try alternative methods for Terminal.app which is often in System Applications
            if !isInstalled && app.bundleIdentifier == "com.apple.Terminal" {
                // Try looking in standard locations
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
    
    // Launch SSH connection in terminal
    func launchSSH(host: String, username: String?, port: String?, identityFile: String?, terminal: TerminalApp) async -> Bool {
        // 构建完整的SSH命令
        var sshCommand = "ssh"
        
        // 添加用户名参数 (如果提供)
        if let username = username, !username.isEmpty {
            sshCommand += " \(username)@\(host)"
        } else {
            sshCommand += " \(host)"
        }
        
        // 添加端口参数 (如果提供)
        if let port = port, !port.isEmpty, port != "22" {
            sshCommand += " -p \(port)"
        }
        
        // 添加身份文件参数 (如果提供)
        if let identityFile = identityFile, !identityFile.isEmpty {
            // 转换~到完整路径
            let expandedPath = (identityFile as NSString).expandingTildeInPath
            // 确保路径正确引用，防止空格问题
            let escapedPath = expandedPath.replacingOccurrences(of: " ", with: "\\ ")
            sshCommand += " -i \(escapedPath)"
        }
        
        return await launchTerminalWithCommand(terminal: terminal, command: sshCommand)
    }
    
    // Internal method to launch terminal with a command
    private func launchTerminalWithCommand(terminal: TerminalApp, command: String) async -> Bool {
        let script: String
        
        switch terminal.bundleIdentifier {
        case "com.apple.Terminal":
            // AppleScript for Terminal
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
            // AppleScript for iTerm2
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
                    -- 如果没有窗口，创建一个新窗口
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
                // 检查具体错误码
                if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int {
                    // 1743和1744是常见的权限错误
                    if errorNumber == -1743 || errorNumber == -1744 {
                        print("🔑 检测到权限错误")
                    }
                }
                
                return false
            }
            
            return true
        }
        
        return false
    }
}
