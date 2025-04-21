import ArgumentParser
import Foundation

// 全局辅助类来管理verbose标志
class GlobalOptions {
    static var verbose = false
}

struct ConfigForgeCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "cf",
        abstract: "ConfigForge CLI - Manage SSH and Kubernetes configurations",
        subcommands: [
            SSHCommand.self,
            KubeCommand.self
        ],
        defaultSubcommand: SSHCommand.self
    )
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false
    
    func run() throws {
        // 设置全局verbose标志
        GlobalOptions.verbose = verbose
        // 当没有子命令时显示帮助
        print(Self.helpMessage())
    }
}

// Start the CLI
ConfigForgeCLI.main() 