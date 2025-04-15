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

// 终端启动服务
actor TerminalLauncherService {
    // 支持的终端应用
    static let supportedTerminalApps: [TerminalApp] = [
        TerminalApp(name: "Terminal", bundleIdentifier: "com.apple.Terminal"),
        TerminalApp(name: "iTerm", bundleIdentifier: "com.googlecode.iterm2")
    ]
    
    // 单例实例
    static let shared = TerminalLauncherService()
    
    // 权限状态
    private var permissionRequested = false
    
    private init() {}
    
    // 获取已安装的终端应用
    func getInstalledTerminalApps() async -> [TerminalApp] {
        var result: [TerminalApp] = []
        
        for app in Self.supportedTerminalApps {
            // 使用标准 NSWorkspace 方法检查
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
            let isInstalled = url != nil
            
            // 对 Terminal.app 尝试备用方法，它通常在系统应用程序中
            if !isInstalled && app.bundleIdentifier == "com.apple.Terminal" {
                // 在标准位置查找
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
    
    // 启动 SSH 连接
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
    
    // 内部方法，使用命令启动终端
    private func launchTerminalWithCommand(terminal: TerminalApp, command: String) async -> Bool {
        // 构建 AppleScript 脚本
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
        
        // 首先尝试 NSAppleScript 执行
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&error)
            
            if let error = error {
                // 检查权限错误
                if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int, 
                   (errorNumber == -1743 || errorNumber == -1744) {
                    // 权限错误，尝试通过 osascript 执行
                    return await executeWithOsascript(script: script)
                }
                return false
            }
            return true
        }
        
        // 如果 NSAppleScript 创建失败，尝试 osascript
        return await executeWithOsascript(script: script)
    }
    
    // 使用 osascript 命令执行
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
    
    // 主动触发 AppleScript 权限请求
    func requestAutomationPermission(for terminal: TerminalApp) async {
        if permissionRequested { return }
        
        // 使用更强力的命令触发权限请求
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
        
        // 尝试执行权限请求
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            _ = appleScript.executeAndReturnError(&error)
            
            // 如果失败，尝试 osascript
            if error != nil {
                _ = await executeWithOsascript(script: script)
            }
        }
        
        permissionRequested = true
    }
}
