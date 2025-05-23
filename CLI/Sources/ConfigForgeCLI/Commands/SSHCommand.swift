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
                let hostName = entry.host
                let number = index + 1
                
                if detail {
                    print("  \(number). \(hostName)")
                    // Display all directives for this host
                    for directive in entry.directives {
                        print("      \(directive.key): \(directive.value)")
                    }
                    print("")
                } else {
                    print("  \(number). \(hostName)")
                }
            }
            
            if !detail {
                print("")
                print("Use 'cf c <number>' or 'cf c <hostname>' to connect")
                print("Use 'cf s <number>' or 'cf s <hostname>' to show details")
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
    
    @Argument(help: "The SSH host number or name to show details for")
    var host: String
    
    func run() throws {
        let fileManager = CLISSHConfigFileManager()
        
        do {
            let entries = try fileManager.getAllHosts()
            
            let entry: SSHConfigEntry
            
            // Check if input is a number
            if let index = Int(host), index > 0, index <= entries.count {
                entry = entries[index - 1]
            } else {
                // Search by host name
                guard let foundEntry = entries.first(where: { $0.host == host }) else {
                    print("Error: Host '\(host)' not found in SSH config.")
                    print("Use 'cf l' to see available hosts.")
                    throw ExitCode.failure
                }
                entry = foundEntry
            }
            
            print("Host: \(entry.host)")
            
            // Iterate through all directives and print them
            for directive in entry.directives {
                print("   \(directive.key): \(directive.value)")
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
    
    @Argument(help: "The SSH host number or name to connect to")
    var host: String
    
    @Flag(name: .long, help: "Enable debug mode to show detailed connection diagnostics")
    var debug = false
    
    func run() throws {
        let isDebugMode = debug || GlobalOptions.verbose
        let fileManager = CLISSHConfigFileManager()
        
        do {
            let entries = try fileManager.getAllHosts()
            
            let hostEntry: SSHConfigEntry
            let hostDisplayName: String
            
            // Check if input is a number
            if let index = Int(host), index > 0, index <= entries.count {
                hostEntry = entries[index - 1]
                hostDisplayName = "\(index). \(hostEntry.host)"
            } else {
                // Search by host name
                guard let foundEntry = entries.first(where: { $0.host == host }) else {
                    print("Error: Host '\(host)' not found in SSH config.")
                    print("Use 'cf l' to see available hosts.")
                    throw ExitCode.failure
                }
                hostEntry = foundEntry
                hostDisplayName = hostEntry.host
            }
            
            if isDebugMode {
                printDebugInfo(host: hostDisplayName, hostEntry: hostEntry)
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
                targetAddress = hostEntry.host // Updated since host is now non-optional
            }
            argsArray.append(targetAddress)
            
            print("Connecting to \(hostDisplayName)...")
            
            if isDebugMode {
                print("Full command: \(sshCommand) \(argsArray.joined(separator: " "))")
            }
            
            let args: [UnsafeMutablePointer<CChar>?] = [strdup(sshCommand)] + argsArray.map { strdup($0) } + [nil]
            execv(sshCommand, args)
            
            print("Error: Failed to start SSH session")
            throw ExitCode.failure
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
    
    private func printDebugInfo(host: String, hostEntry: SSHConfigEntry) {
        print("======= Debug Information =======")
        print("Searching for host configuration: \(host)")
        print("Current working directory: \(FileManager.default.currentDirectoryPath)")
        print("System version: \(ProcessInfo.processInfo.operatingSystemVersionString)")
        
        print("\n===== Host Configuration Information =====")
        print("Host: \(hostEntry.host)")
        print("Hostname: \(hostEntry.hostname ?? "not specified")")
        print("User: \(hostEntry.user ?? "not specified")")
        print("Port: \(hostEntry.port ?? "not specified (default: 22)")")
        print("IdentityFile: \(hostEntry.identityFile ?? "not specified")")
        
        print("\n===== SSH Connection Information =====")
        print("Enable SSH highest debug mode (-vvv)")
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