import SwiftUI

struct TerminalLauncherButton: View {
    let sshEntry: SSHConfigEntry
    @State private var installedTerminals: [TerminalApp] = []
    @State private var showingNoTerminalAlert = false
    @State private var showingPermissionAlert = false
    @State private var currentTerminal: TerminalApp?
    
    // 使用 @AppStorage 存储权限请求状态
    @AppStorage("ConfigForge.DidRequestTerminalPermission") 
    private var didRequestPermission: Bool = false
    
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
                } label: {
                    Label(L10n.Terminal.Open.in, systemImage: "terminal")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            } else if installedTerminals.count == 1 {
                // If only one terminal is available, show direct button
                Button(action: {
                    Task { await launchSSHInTerminal(terminal: installedTerminals[0]) }
                }) {
                    let terminalName = installedTerminals[0].name
                    Label(terminalName, systemImage: terminalIconName(for: installedTerminals[0]))
                        .frame(minWidth: 80)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(6)
                }
            } else {
                // No terminals found - show disabled button
                Button(action: {
                    showingNoTerminalAlert = true
                }) {
                    Label(L10n.Terminal.Open.in, systemImage: "terminal")
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
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
            }
        }
        .alert(isPresented: $showingPermissionAlert) {
            Alert(
                title: Text(L10n.Terminal.Launch.Failed.title),
                message: Text(currentTerminal != nil ? L10n.Terminal.Launch.Failed.message(currentTerminal!.name) : "无法启动终端"),
                primaryButton: .default(Text("打开系统设置")) {
                    openPrivacySettings()
                },
                secondaryButton: .cancel(Text("取消"))
            )
        }
    }
    
    // 打开隐私设置
    private func openPrivacySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
            NSWorkspace.shared.open(url)
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
        // 首次使用或重启后请求权限
        if !didRequestPermission {
            await TerminalLauncherService.shared.requestAutomationPermission(for: terminal)
            didRequestPermission = true
        }
        
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
            await MainActor.run {
                currentTerminal = terminal
                showingPermissionAlert = true
            }
        }
    }
} 