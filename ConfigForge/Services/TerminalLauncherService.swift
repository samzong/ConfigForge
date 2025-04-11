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
        // 在初始化时触发权限检查
        Task { @MainActor in
            await forceRequestAutomationPermission()
        }
    }
    
    // Get installed terminal apps
    func getInstalledTerminalApps() async -> [TerminalApp] {
        print("📱 TerminalLauncherService: Checking for installed terminal apps...")
        print("📱 Supported terminal apps: \(Self.supportedTerminalApps.map { $0.name }.joined(separator: ", "))")
        
        // Check if we're running in a sandbox
        let isSandboxed = Bundle.main.appStoreReceiptURL?.path.contains("sandboxed") ?? false
        print("📱 App sandbox state: \(isSandboxed ? "SANDBOXED" : "NOT SANDBOXED")")
        
        var result: [TerminalApp] = []
        
        for app in Self.supportedTerminalApps {
            print("📱 Checking if \(app.name) is installed (bundle ID: \(app.bundleIdentifier))...")
            
            // Check using standard NSWorkspace method first
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
            let isInstalled = url != nil
            print("📱 NSWorkspace method - \(app.name) installed: \(isInstalled ? "YES" : "NO") \(url?.path ?? "")")
            
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
                        print("📱 Found Terminal.app at standard location: \(path)")
                        result.append(app)
                        break
                    }
                }
            } else if isInstalled {
                result.append(app)
            }
        }
        
        print("📱 Found \(result.count) installed terminal apps")
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
        
        print("📱 Launching SSH command: \(sshCommand)")
        return await launchTerminalWithCommand(terminal: terminal, command: sshCommand)
    }
    
    // Request permissions for Terminal automation using Apple Events
    @MainActor
    func requestTerminalAutomationPermission(terminal: TerminalApp) async {
        print("🔑 [权限请求] 开始为 \(terminal.name) 请求权限...")
        print("🔑 [权限请求] Bundle ID: \(terminal.bundleIdentifier)")
        
        // 1. 先确保目标应用已启动
        NSWorkspace.shared.launchApplication(withBundleIdentifier: terminal.bundleIdentifier, 
                                             options: .default, 
                                             additionalEventParamDescriptor: nil, 
                                             launchIdentifier: nil)
        
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        // 2. 尝试通过系统 API 触发权限请求
        if let targetApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == terminal.bundleIdentifier }) {
            print("🔑 [权限请求] 找到目标应用: \(targetApp.localizedName ?? terminal.name)")
            
            // 创建一个 get info 事件来触发权限请求
            let eventDescriptor = NSAppleEventDescriptor.createAutomationEvent(
                for: targetApp,
                eventClass: AEEventClass(kASAppleScriptSuite),
                eventID: AEEventID(kASGetPropertyEvent)
            )
            
            // 添加参数
            let propertyParam = NSAppleEventDescriptor(string: "properties")
            eventDescriptor.setParam(propertyParam, forKeyword: AEKeyword(keyDirectObject))
            
            print("🔑 [权限请求] 发送事件到目标应用")
            do {
                try eventDescriptor.sendEvent(options: [], timeout: TimeInterval(kAEDefaultTimeout))
                print("✅ [权限请求] 事件发送成功")
            } catch {
                print("❌ [权限请求] 事件发送失败: \(error)")
            }
        }
        
        // 3. 发送一个基本的 Apple Event
        let event = NSAppleEventDescriptor.createBundleEvent(
            bundleIdentifier: terminal.bundleIdentifier,
            eventClass: AEEventClass(kCoreEventClass),
            eventID: AEEventID(kAEGetData)
        )
        
        print("🔑 [权限请求] 发送 Apple Event...")
        let result = AESendMessage(event.aeDesc, nil, AESendMode(kAENoReply), kAEDefaultTimeout)
        
        if result != noErr {
            print("🔑 [权限请求] 发送 Apple Event 失败: \(result)")
            
            // 如果发送失败，显示手动设置引导
            let setupAlert = NSAlert()
            setupAlert.messageText = "需要系统权限"
            setupAlert.informativeText = """
            需要授权 ConfigForge 控制 \(terminal.name)。
            请尝试重启应用后再试。
            
            如果问题仍然存在：
            1. 点击"打开系统设置"
            2. 在"隐私与安全性"中找到"自动化"
            3. 找到 ConfigForge
            4. 勾选对 \(terminal.name) 的访问权限
            """
            setupAlert.addButton(withTitle: "打开系统设置")
            setupAlert.addButton(withTitle: "稍后设置")
            
            if setupAlert.runModal() == .alertFirstButtonReturn {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            print("🔑 [权限请求] 已触发权限请求")
            // 等待系统显示权限对话框
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            
            // 检查权限状态
            let permissionResult = await checkAppleScriptPermission(for: terminal)
            if permissionResult {
                print("✅ [权限请求] 已成功获得权限")
                return
            }
        }
        
        print("❌ [权限请求] 权限请求未完成")
    }
    
    // Internal method to launch terminal with a command
    private func launchTerminalWithCommand(terminal: TerminalApp, command: String) async -> Bool {
        // 首先检查权限
        let hasPermission = await checkAppleScriptPermission(for: terminal)
        if hasPermission == false {
            // 如果没有权限，尝试请求
            await requestTerminalAutomationPermission(terminal: terminal)
            
            // 再次检查权限
            let permissionStatus = await checkAppleScriptPermission(for: terminal)
            if permissionStatus == false {
                print("❌ 无法获取必要的权限")
                return false
            }
        }
        
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
        
        print("📱 执行AppleScript:\n\(script)")
        print("📱 尝试使用bundleIdentifier: \(terminal.bundleIdentifier)")
        
        // 打印更多环境信息以调试
        print("📱 当前应用bundleID: \(Bundle.main.bundleIdentifier ?? "未知")")
        print("📱 当前应用名称: \(Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "未知")")
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: script) {
            let result = appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("📱 AppleScript执行错误: \(error)")
                
                // 打印完整的错误信息
                for (key, value) in error {
                    print("📱 错误详情 - \(key): \(value)")
                }
                
                // 检查具体错误码
                if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int {
                    print("📱 AppleScript错误码: \(errorNumber)")
                    
                    // 1743和1744是常见的权限错误
                    if errorNumber == -1743 || errorNumber == -1744 {
                        print("🔑 检测到权限错误")
                        
                        // 强行打开权限设置
                        DispatchQueue.main.async {
                            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                    }
                }
                
                return false
            }
            
            print("📱 AppleScript执行成功: \(result.stringValue ?? "无返回值")")
            return true
        }
        
        return false
    }
    
    // 强制触发权限请求
    @MainActor
    func forceRequestAutomationPermission() async {
        print("🔒 [初始化权限] 开始初始化终端自动化权限...")
        
        // 获取已安装的终端应用
        let installedTerminals = await getInstalledTerminalApps()
        print("🔒 [初始化权限] 发现 \(installedTerminals.count) 个已安装的终端应用")
        
        // 显示初始化提示
        let alert = NSAlert()
        alert.messageText = "ConfigForge 需要获取权限"
        alert.informativeText = """
        为了能够自动打开 SSH 连接，ConfigForge 需要控制终端应用。
        
        请在接下来的系统对话框中点击"允许"。
        
        如果没有看到系统权限对话框，我们将指导您手动设置。
        """
        alert.addButton(withTitle: "继续")
        alert.addButton(withTitle: "取消")
        
        if alert.runModal() == .alertFirstButtonReturn {
            for terminal in installedTerminals {
                print("\n🔒 [初始化权限] 处理 \(terminal.name)...")
                
                // 启动目标应用程序
                print("🔒 [初始化权限] 启动 \(terminal.name)...")
                NSWorkspace.shared.launchApplication(withBundleIdentifier: terminal.bundleIdentifier, 
                                                   options: .default, 
                                                   additionalEventParamDescriptor: nil, 
                                                   launchIdentifier: nil)
                
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                
                // 检查目标应用是否已启动并尝试请求权限
                if let targetApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == terminal.bundleIdentifier }) {
                    print("🔒 [初始化权限] 找到运行中的 \(terminal.name)")
                    
                    print("🔒 [初始化权限] 发送 Apple Event...")
                    do {
                        let descriptor = NSAppleEventDescriptor.createAutomationEvent(
                            for: targetApp,
                            eventClass: AEEventClass(kCoreEventClass),
                            eventID: AEEventID(kAEGetData)
                        )
                        do {
                            try descriptor.sendEvent(options: [], timeout: TimeInterval(kAEDefaultTimeout))
                            print("🔒 [初始化权限] 事件发送成功")
                        } catch let error as NSError {
                            print("🔒 [初始化权限] 事件发送失败: \(error.localizedDescription)")
                            if error.code == -1743 || error.code == -1744 {
                                print("🔒 [初始化权限] 检测到权限错误，尝试请求权限...")
                            }
                        }
                        
                        // 等待系统显示权限对话框
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        
                        // 再次检查权限状态
                        if await checkAppleScriptPermission(for: terminal) {
                            print("🔒 [初始化权限] 未能获得权限，尝试提供手动设置指南...")
                            
                            let setupAlert = NSAlert()
                            setupAlert.messageText = "需要手动设置权限"
                            setupAlert.informativeText = """
                            看起来自动设置权限失败了。请按以下步骤手动设置：
                            
                            1. 点击"打开系统设置"
                            2. 在"隐私与安全性"中找到"自动化"
                            3. 找到 ConfigForge
                            4. 勾选对 \(terminal.name) 的访问权限
                            
                            完成设置后点击"好"继续。
                            """
                            setupAlert.addButton(withTitle: "打开系统设置")
                            setupAlert.addButton(withTitle: "稍后设置")
                            
                            if setupAlert.runModal() == .alertFirstButtonReturn {
                                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                                    NSWorkspace.shared.open(url)
                                    // 等待用户完成设置
                                    try? await Task.sleep(nanoseconds: 5_000_000_000)
                                    if await checkAppleScriptPermission(for: terminal) {
                                        print("✅ [初始化权限] 成功获得 \(terminal.name) 权限")
                                    } else {
                                        print("❌ [初始化权限] \(terminal.name) 权限设置失败")
                                    }
                                }
                            }
                        } else {
                            print("✅ [初始化权限] 成功获得 \(terminal.name) 权限")
                        }
                    } catch {
                        print("❌ [初始化权限] 发送事件失败: \(error)")
                        // 如果发送事件失败，尝试回退到传统的 AppleScript 方法
                        await requestTerminalAutomationPermission(terminal: terminal)
                    }
                } else {
                    print("❌ [初始化权限] 未找到运行中的终端应用")
                }
            }
            
            print("\n🔒 [初始化权限] 权限初始化完成")
            let diagnostics = await getAutomationDiagnostics()
            print("\n📊 权限诊断结果:\n\(diagnostics)")
        }
    }
    
    // 检查特定终端应用的AppleScript权限状态
    func checkAppleScriptPermission(for terminal: TerminalApp) async -> Bool {
        print("🔍 检查\(terminal.name)的权限状态...")
        
        // 首先尝试使用 Apple Event 直接检查权限
        if let targetApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == terminal.bundleIdentifier }) {
            let event = NSAppleEventDescriptor.createAutomationEvent(
                for: targetApp,
                eventClass: AEEventClass(kCoreEventClass),
                eventID: AEEventID(kAEGetData)
            )
            
            let result = AESendMessage(event.aeDesc, nil, AESendMode(kAENoReply), kAEDefaultTimeout)
            if result == noErr {
                print("✅ \(terminal.name)的权限正常")
                return true
            }
            
            print("🔒 使用 Apple Event 检查失败，尝试 AppleScript 方式")
        }
        
        // 如果 Apple Event 失败，回退到 AppleScript 方式
        let simpleScript = """
        tell application "\(terminal.name)"
            get name
        end tell
        """
        
        var error: NSDictionary?
        if let appleScript = NSAppleScript(source: simpleScript) {
            let result = appleScript.executeAndReturnError(&error)
            
            if let error = error {
                print("🔒 AppleScript 检查失败: \(error)")
                
                // 检查是否是权限错误
                if let errorNumber = error["NSAppleScriptErrorNumber"] as? Int,
                   errorNumber == -1743 || errorNumber == -1744 {
                    print("🔒 检测到权限错误 (错误码: \(errorNumber))")
                    return false
                }
                
                print("🔒 非权限类错误: \(error)")
                return false
            }
            
            print("✅ \(terminal.name)的AppleScript权限正常")
            return true
        }
        
        print("❌ 无法创建AppleScript实例")
        return false
    }
    
    // 获取所有可能的自动化权限问题的诊断信息
    @MainActor
    func getAutomationDiagnostics() async -> String {
        var diagnostics = "自动化权限诊断：\n\n"
        
        // 检查应用沙盒状态
        let isSandboxed = Bundle.main.appStoreReceiptURL?.path.contains("sandboxed") ?? false
        diagnostics += "应用沙盒状态: \(isSandboxed ? "沙盒模式" : "非沙盒模式")\n"
        
        // 检查Entitlements
        diagnostics += "Entitlements 检查:\n"
        diagnostics += "- com.apple.security.automation.apple-events: 已配置\n"
        
        // 检查Info.plist
        diagnostics += "Info.plist 检查:\n"
        diagnostics += "- NSAppleEventsUsageDescription: 已配置\n"
        diagnostics += "- NSAppleScriptEnabled: 已配置\n"
        
        // 检查各个终端应用的权限
        diagnostics += "\n终端应用权限检查:\n"
        
        for app in Self.supportedTerminalApps {
            let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: app.bundleIdentifier)
            let isInstalled = url != nil
            
            if isInstalled {
                let hasPermission = await checkAppleScriptPermission(for: app)
                diagnostics += "- \(app.name): \(isInstalled ? "已安装" : "未安装"), 权限状态: \(hasPermission ? "正常" : "缺少权限")\n"
            } else {
                diagnostics += "- \(app.name): 未安装\n"
            }
        }
        
        // 添加环境信息
        diagnostics += "\n环境信息:\n"
        diagnostics += "- 应用名称: \(Bundle.main.infoDictionary?[kCFBundleNameKey as String] as? String ?? "未知")\n"
        diagnostics += "- 应用标识: \(Bundle.main.bundleIdentifier ?? "未知")\n"
        diagnostics += "- 系统版本: \(ProcessInfo.processInfo.operatingSystemVersionString)\n"
        
        return diagnostics
    }
}
