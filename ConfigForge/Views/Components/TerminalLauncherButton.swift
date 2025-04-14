import SwiftUI

struct TerminalLauncherButton: View {
    let sshEntry: SSHConfigEntry
    @State private var installedTerminals: [TerminalApp] = []
    @State private var showingNoTerminalAlert = false
    
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
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
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
                        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                            NSWorkspace.shared.open(url)
                        }
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
                    Label("terminal.open.in".cfLocalized, systemImage: "terminal")
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
                // Get installed terminals
                installedTerminals = await TerminalLauncherService.shared.getInstalledTerminalApps()
                
                if installedTerminals.isEmpty {
                    // No terminal apps were detected. Terminal launcher button will be shown as disabled.
                }
            }
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
        // 获取SSH条目的详细信息
        let hostname = sshEntry.hostname.isEmpty ? sshEntry.host : sshEntry.hostname
        
        // 启动SSH连接，传递所有必要参数
        let success = await TerminalLauncherService.shared.launchSSH(
            host: hostname,
            username: sshEntry.user,
            port: sshEntry.port,
            identityFile: sshEntry.identityFile,
            terminal: terminal
        )
        
        if !success {
            await showPermissionAlert(terminal: terminal) // Assume failure is likely due to permissions
        }
    }
    
    // 显示权限错误提示
    @MainActor
    private func showPermissionAlert(terminal: TerminalApp) {
        let alert = NSAlert()
        alert.messageText = "terminal.launch.failed.title".cfLocalized
        alert.informativeText = String(format: "terminal.launch.failed.message".cfLocalized, terminal.name)
        alert.addButton(withTitle: "打开系统设置")
        alert.addButton(withTitle: "取消")
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // 打开系统设置
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        }
    }
} 