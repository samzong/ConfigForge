import ArgumentParser
import Foundation

struct SSHCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ssh",
        abstract: "Manage SSH configurations",
        discussion: "Commands for working with SSH hosts and connections",
        subcommands: [
            SSHListCommand.self,
            SSHConnectCommand.self,
            SSHShowCommand.self
        ]
    )
    
    func run() throws {
        print(Self.helpMessage())
    }
}

struct SSHListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all SSH hosts",
        aliases: ["ls","l"]
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed information for each host")
    var detail = false
    
    func run() throws {
        let fileManager = CLISSHConfigFileManager()
        
        do {
            let entries = try fileManager.getAllHosts()
            
            if entries.isEmpty {
                print("No SSH hosts found.")
                return
            }
            
            print("Available SSH hosts:")
            for (index, entry) in entries.enumerated() {
                if detail {
                    print("\(index + 1). \(entry.host ?? "unnamed")")
                    if let user = entry.user {
                        print("   User: \(user)")
                    }
                    if let hostname = entry.hostname {
                        print("   Hostname: \(hostname)")
                    }
                    if let port = entry.port {
                        print("   Port: \(port)")
                    }
                    if let identityFile = entry.identityFile {
                        print("   IdentityFile: \(identityFile)")
                    }
                    if let forwardAgent = entry.forwardAgent {
                        print("   ForwardAgent: \(forwardAgent)")
                    }
                    if let proxyCommand = entry.proxyCommand {
                        print("   ProxyCommand: \(proxyCommand)")
                    }
                    print("")
                } else {
                    print("\(index + 1). \(entry.host ?? "unnamed")")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct SSHShowCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "show",
        abstract: "Show detailed information for a specific SSH host",
        aliases: ["s"]
    )
    
    @Argument(help: "The SSH host to show details for")
    var host: String
    
    func run() throws {
        let fileManager = CLISSHConfigFileManager()
        
        do {
            let entries = try fileManager.getAllHosts()
            
            guard let entry = entries.first(where: { $0.host == host }) else {
                print("Error: Host '\(host)' not found in SSH config.")
                throw ExitCode.failure
            }
            
            print("Host: \(entry.host ?? "unnamed")")
            
            if let hostname = entry.hostname {
                print("   Hostname: \(hostname)")
            }
            if let user = entry.user {
                print("   User: \(user)")
            }
            if let port = entry.port {
                print("   Port: \(port)")
            }
            if let identityFile = entry.identityFile {
                print("   IdentityFile: \(identityFile)")
            }
            if let forwardAgent = entry.forwardAgent {
                print("   ForwardAgent: \(forwardAgent)")
            }
            if let proxyCommand = entry.proxyCommand {
                print("   ProxyCommand: \(proxyCommand)")
            }
            if let serverAliveInterval = entry.serverAliveInterval {
                print("   ServerAliveInterval: \(serverAliveInterval)")
            }
            if let serverAliveCountMax = entry.serverAliveCountMax {
                print("   ServerAliveCountMax: \(serverAliveCountMax)")
            }
            if let strictHostKeyChecking = entry.strictHostKeyChecking {
                print("   StrictHostKeyChecking: \(strictHostKeyChecking)")
            }
            if let userKnownHostsFile = entry.userKnownHostsFile {
                print("   UserKnownHostsFile: \(userKnownHostsFile)")
            }
            if let connectTimeout = entry.connectTimeout {
                print("   ConnectTimeout: \(connectTimeout)")
            }
            
            if !entry.otherOptions.isEmpty {
                print("   Other Options:")
                for (key, value) in entry.otherOptions {
                    print("      \(key): \(value)")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

struct SSHConnectCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "connect",
        abstract: "Connect to a specified SSH host",
        aliases: ["c"]
    )
    
    @Argument(help: "The SSH host to connect to")
    var host: String
    
    @Flag(name: .long, help: "Enable debug mode to show detailed connection diagnostics")
    var debug = false
    
    func run() throws {
        let isDebugMode = debug || GlobalOptions.verbose
        let fileManager = CLISSHConfigFileManager()
        
        do {
            let entries = try fileManager.getAllHosts()
            
            guard let hostEntry = entries.first(where: { $0.host == host }) else {
                print("错误: 在SSH配置中找不到主机 '\(host)'")
                throw ExitCode.failure
            }
            
            if isDebugMode {
                printDebugInfo(host: host, hostEntry: hostEntry)
            }
            
            let sshCommand = "/usr/bin/ssh"
            var argsArray = [String]()
            
            if isDebugMode {
                argsArray.append("-v")
                argsArray.append("-v")
                argsArray.append("-v")
            }
            
            if let port = hostEntry.port {
                argsArray.append("-p")
                argsArray.append(port)
            }
            
            if let identityFile = hostEntry.identityFile {
                argsArray.append("-i")
                argsArray.append(identityFile)
            }
            
            configureConnectionParameters(argsArray: &argsArray, hostEntry: hostEntry, isDebug: isDebugMode)
            
            var targetAddress = ""
            if let username = hostEntry.user, let hostname = hostEntry.hostname {
                targetAddress = "\(username)@\(hostname)"
            } else {
                targetAddress = host
            }
            argsArray.append(targetAddress)
            
            print("正在连接到 \(host)...")
            
            if isDebugMode {
                print("完整命令: \(sshCommand) \(argsArray.joined(separator: " "))")
            }
            
            let args: [UnsafeMutablePointer<CChar>?] = [strdup(sshCommand)] + argsArray.map { strdup($0) } + [nil]
            execv(sshCommand, args)
            
            print("错误: 无法启动SSH会话")
            throw ExitCode.failure
        } catch {
            print("错误: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func printDebugInfo(host: String, hostEntry: SSHConfigEntry) {
        print("======= 调试信息 =======")
        print("正在查找主机配置: \(host)")
        print("当前工作目录: \(FileManager.default.currentDirectoryPath)")
        print("系统版本: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        
        print("\n===== 主机配置信息 =====")
        print("主机: \(hostEntry.host ?? "未命名")")
        print("主机名: \(hostEntry.hostname ?? "未指定")")
        print("用户: \(hostEntry.user ?? "未指定")")
        print("端口: \(hostEntry.port ?? "未指定 (默认: 22)")")
        print("身份文件: \(hostEntry.identityFile ?? "未指定")")
        
        print("\n===== SSH连接信息 =====")
        print("启用SSH最高调试模式 (-vvv)")
    }
    
    private func configureConnectionParameters(argsArray: inout [String], hostEntry: SSHConfigEntry, isDebug: Bool) {
        if isDebug {
            argsArray.append("-o")
            argsArray.append("LogLevel=DEBUG3")
        }
        
        let aliveInterval = hostEntry.serverAliveInterval ?? "15"
        argsArray.append("-o")
        argsArray.append("ServerAliveInterval=\(aliveInterval)")
        
        let aliveCountMax = hostEntry.serverAliveCountMax ?? "3"
        argsArray.append("-o")
        argsArray.append("ServerAliveCountMax=\(aliveCountMax)")
        
        let connectTimeout = hostEntry.connectTimeout ?? "10"
        argsArray.append("-o")
        argsArray.append("ConnectTimeout=\(connectTimeout)")
    }
} 