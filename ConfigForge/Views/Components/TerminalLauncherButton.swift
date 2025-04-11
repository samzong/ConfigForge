import SwiftUI

struct TerminalLauncherButton: View {
    let sshEntry: SSHConfigEntry
    @State private var isShowingMenu = false
    @State private var installedTerminals: [TerminalApp] = []
    @State private var showingNoTerminalAlert = false
    @State private var showingPermissionHelp = false
    
    var body: some View {
        Group {
            if installedTerminals.count > 1 {
                // If multiple terminals are available, show dropdown
                Menu {
                    ForEach(installedTerminals, id: \.bundleIdentifier) { terminal in
                        Button(action: {
                            Task { await launchSSHInTerminal(terminal: terminal) }
                        }) {
                            Label(terminal.name, systemImage: terminalIconName(for: terminal))
                        }
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showingPermissionHelp = true
                    }) {
                        Label("权限设置帮助", systemImage: "lock.shield")
                    }
                } label: {
                    Label("terminal.open.in".cfLocalized, systemImage: "terminal")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            } else if installedTerminals.count == 1 {
                // If only one terminal is available, show direct button
                Menu {
                    Button(action: {
                        Task { await launchSSHInTerminal(terminal: installedTerminals[0]) }
                    }) {
                        let terminalName = installedTerminals[0].name
                        let buttonText = terminalName == "Terminal" ? "terminal.open.in.terminal".cfLocalized : "terminal.open.in.iterm".cfLocalized
                        Label(buttonText, systemImage: terminalIconName(for: installedTerminals[0]))
                    }
                    
                    Divider()
                    
                    Button(action: {
                        showingPermissionHelp = true
                    }) {
                        Label("权限设置帮助", systemImage: "lock.shield")
                    }
                } label: {
                    let terminalName = installedTerminals[0].name
                    let buttonText = terminalName == "Terminal" ? "terminal.open.in.terminal".cfLocalized : "terminal.open.in.iterm".cfLocalized
                    
                    Label(buttonText, systemImage: terminalIconName(for: installedTerminals[0]))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            } else {
                // No terminals found - show disabled button
                Button(action: {
                    showingNoTerminalAlert = true
                }) {
                    Label("terminal.open.in".cfLocalized, systemImage: "terminal.slash")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 6)
                        .background(Color.gray)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                        .opacity(0.7)
                }
                .disabled(true)
                .help("No terminal applications detected")
                .alert("Terminal Not Found", isPresented: $showingNoTerminalAlert) {
                    Button("OK", role: .cancel) { }
                } message: {
                    Text("No terminal applications were detected. Please make sure Terminal.app or iTerm.app is installed and try again.")
                }
            }
        }
        .onAppear {
            Task {
                // Debug the SSH entry data first
                print("🔑 SSH Entry being used for terminal button:")
                print("🔑   - Host: \(sshEntry.host)")
                print("🔑   - Hostname: \(sshEntry.hostname)")
                print("🔑   - User: \(sshEntry.user)")
                print("🔑   - Port: \(sshEntry.port)")
                print("🔑   - Identity File: \(sshEntry.identityFile)")
                
                print("🔍 TerminalLauncherButton: Checking for installed terminals...")
                
                // Debug: Check if Terminal.app is installed
                let terminalURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Terminal")
                print("🔍 Terminal.app URL: \(terminalURL?.path ?? "Not found")")
                
                // Debug: Check if iTerm.app is installed
                let iTermURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.googlecode.iterm2")
                print("🔍 iTerm.app URL: \(iTermURL?.path ?? "Not found")")
                
                // Check if Terminal.app exists at standard locations
                let terminalPaths = ["/System/Applications/Utilities/Terminal.app", "/Applications/Utilities/Terminal.app"]
                for path in terminalPaths {
                    print("🔍 Checking if Terminal.app exists at: \(path)")
                    print("🔍   - Exists: \(FileManager.default.fileExists(atPath: path))")
                }
                
                // Get installed terminals
                installedTerminals = await TerminalLauncherService.shared.getInstalledTerminalApps()
                print("🔍 Found \(installedTerminals.count) installed terminals:")
                installedTerminals.forEach { terminal in
                    print("🔍   - \(terminal.name) (\(terminal.bundleIdentifier))")
                }
                
                if installedTerminals.isEmpty {
                    print("⚠️ No terminal apps were detected. Terminal launcher button will be shown as disabled.")
                }
            }
        }
        .alert("手动配置权限", isPresented: $showingPermissionHelp) {
            Button("打开系统设置") {
                Task {
                    // 强制触发权限请求
                    await TerminalLauncherService.shared.forceRequestAutomationPermission()
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text("""
            如果终端无法正常打开，需要在系统设置中手动授予权限:
            
            1. 打开系统设置 > 隐私与安全性 > 自动化
            2. 确保在列表中有ConfigForge应用
            3. 勾选允许ConfigForge控制"Terminal"或"iTerm"
            """)
        }
    }
    
    // Return appropriate icon name based on terminal type
    private func terminalIconName(for terminal: TerminalApp) -> String {
        switch terminal.bundleIdentifier {
        case "com.apple.Terminal":
            return "terminal"
        case "com.googlecode.iterm2":
            return "terminal.fill"
        default:
            return "terminal"
        }
    }
    
    private func launchSSHInTerminal(terminal: TerminalApp) async {
        // 首先，请求权限（如果需要）
        await TerminalLauncherService.shared.requestTerminalAutomationPermission(terminal: terminal)
        
        // 检查权限状态
        let hasPermission = await TerminalLauncherService.shared.checkAppleScriptPermission(for: terminal)
        
        if !hasPermission {
            print("⚠️ 缺少控制\(terminal.name)的权限，尝试请求权限...")
            await TerminalLauncherService.shared.forceRequestAutomationPermission()
            
            // 再次检查权限
            let permissionGranted = await TerminalLauncherService.shared.checkAppleScriptPermission(for: terminal)
            if !permissionGranted {
                print("❌ 权限请求失败，无法继续")
                await showPermissionAlert(terminal: terminal)
                return
            }
        }
        
        // 获取SSH条目的详细信息
        let hostname = sshEntry.hostname.isEmpty ? sshEntry.host : sshEntry.hostname
        print("🔑 尝试使用\(terminal.name)启动SSH连接到\(hostname)")
        
        // 启动SSH连接，传递所有必要参数
        let success = await TerminalLauncherService.shared.launchSSH(
            host: hostname,
            username: sshEntry.user,
            port: sshEntry.port,
            identityFile: sshEntry.identityFile,
            terminal: terminal
        )
        
        if !success {
            await showSSHFailedAlert(terminal: terminal)
        }
    }
    
    // 显示权限错误提示
    @MainActor
    private func showPermissionAlert(terminal: TerminalApp) {
        let alert = NSAlert()
        alert.messageText = "需要控制\(terminal.name)的权限"
        alert.informativeText = """
        ConfigForge需要权限才能控制\(terminal.name)来启动SSH连接。
        
        请按照以下步骤授予权限:
        1. 打开系统设置 > 隐私与安全性 > 自动化
        2. 找到ConfigForge应用（如果未列出，请先尝试使用该功能一次）
        3. 勾选允许控制\(terminal.name)的选项
        
        授予权限后再次尝试连接。
        """
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "显示诊断信息")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        } else if response == .alertSecondButtonReturn {
            // 显示诊断信息
            Task {
                let diagnostics = await TerminalLauncherService.shared.getAutomationDiagnostics()
                let diagAlert = NSAlert()
                diagAlert.messageText = "自动化权限诊断"
                diagAlert.informativeText = diagnostics
                diagAlert.addButton(withTitle: "复制到剪贴板")
                diagAlert.addButton(withTitle: "关闭")
                
                let diagResponse = diagAlert.runModal()
                if diagResponse == .alertFirstButtonReturn {
                    // 复制到剪贴板
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(diagnostics, forType: .string)
                }
            }
        }
    }
    
    // 显示SSH连接失败提示
    @MainActor
    private func showSSHFailedAlert(terminal: TerminalApp) {
        let alert = NSAlert()
        alert.messageText = "terminal.launch.failed.title".cfLocalized
        alert.informativeText = """
        无法在\(terminal.name)中启动SSH连接。可能的原因:
        
        1. 应用没有控制\(terminal.name)的权限
        2. SSH配置参数有误
        3. 身份文件路径不正确或无法访问
        
        请检查SSH配置并确保已授予必要权限。
        """
        
        alert.addButton(withTitle: "app.confirm".cfLocalized)
        alert.addButton(withTitle: "检查权限设置")
        alert.addButton(withTitle: "查看详细诊断")
        
        let response = alert.runModal()
        if response == .alertSecondButtonReturn {
            // 用户点击了"检查权限设置"按钮
            Task {
                await TerminalLauncherService.shared.forceRequestAutomationPermission()
            }
        } else if response == .alertThirdButtonReturn {
            // 显示详细诊断
            Task {
                let diagnostics = await TerminalLauncherService.shared.getAutomationDiagnostics()
                let diagAlert = NSAlert()
                diagAlert.messageText = "详细诊断信息"
                diagAlert.informativeText = diagnostics
                diagAlert.addButton(withTitle: "关闭")
                diagAlert.runModal()
            }
        }
    }
} 