import ArgumentParser
import Foundation


struct KubeCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "kube",
        abstract: "Manage Kubernetes configurations",
        discussion: "Commands for managing Kubernetes contexts and configurations",
        subcommands: [
            KubeCurrentCommand.self,
            KubeListCommand.self,
            KubeSetCommand.self
        ],
        aliases: ["k", "kubectl"]
    )
    
    func run() throws {
        print(KubeCommand.helpMessage())
    }
}

// List Kubernetes contexts
struct KubeListCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all Kubernetes contexts",
        aliases: ["ls","l"]
    )
    
    @Flag(name: .shortAndLong, help: "Show detailed information for each context")
    var detail = false
    
    func run() throws {
        let fileManager = CLIKubeConfigFileManager()
        
        do {
            let kubeConfig = try fileManager.getKubeConfig()
            let contexts = kubeConfig.contexts
            let currentContext = kubeConfig.currentContext
            
            if contexts.isEmpty {
                print("No Kubernetes contexts found.")
                return
            }
            
            print("Available Kubernetes contexts:")
            for (index, context) in contexts.enumerated() {
                let isCurrent = context.name == currentContext ? " (current)" : ""
                if detail {
                    print("\(index + 1). \(context.name)\(isCurrent)")
                    if let cluster = context.context.cluster {
                        print("   Cluster: \(cluster)")
                    }
                    if let namespace = context.context.namespace {
                        print("   Namespace: \(namespace)")
                    }
                    if let user = context.context.user {
                        print("   User: \(user)")
                    }
                    print("")
                } else {
                    print("\(index + 1). \(context.name)\(isCurrent)")
                }
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
}

// Switch to a Kubernetes context (renamed from KubeContextCommand to KubeSetCommand)
struct KubeSetCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "set",
        abstract: "Set the active Kubernetes context",
        discussion: "Select a Kubernetes context to use",
        aliases: ["s", "context", "use"]
    )
    
    @Argument(help: "The name of the Kubernetes context to set as active")
    var contextName: String
    
    func run() throws {
        if GlobalOptions.verbose {
            print("Verbose mode enabled")
            print("Setting Kubernetes context to: \(contextName)")
        }
        
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/kubectl")
        process.arguments = ["config", "use-context", contextName]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = errorPipe
        
        if GlobalOptions.verbose {
            print("Executing command: kubectl config use-context \(contextName)")
        }
        
        do {
            try process.run()
            process.waitUntilExit()
            
            if GlobalOptions.verbose {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                if let output = String(data: outputData, encoding: .utf8), !output.isEmpty {
                    print("Command output: \(output)")
                }
            }
            
            if process.terminationStatus == 0 {
                print("Switched to context \"\(contextName)\".")
            } else {
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let errorMessage = String(data: errorData, encoding: .utf8) ?? "Unknown error"
                print("Failed to switch context: \(errorMessage)")
                
                if GlobalOptions.verbose {
                    print("Command failed with exit code: \(process.terminationStatus)")
                }
                
                throw ExitCode(1)
            }
        } catch {
            print("Failed to execute command: \(error.localizedDescription)")
            
            if GlobalOptions.verbose {
                print("Exception details: \(error)")
            }
            
            throw ExitCode(1)
        }
    }
}

// Show current Kubernetes context
struct KubeCurrentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "current",
        abstract: "Show the current Kubernetes context",
        aliases: ["c"]
    )
    
    func run() throws {
        let fileManager = CLIKubeConfigFileManager()
        
        do {
            let kubeConfig = try fileManager.getKubeConfig()
            
            if let currentContext = kubeConfig.currentContext, !currentContext.isEmpty {
                print("Current context: \(currentContext)")
            } else {
                print("No current Kubernetes context set.")
            }
        } catch {
            print("Error: \(error.localizedDescription)")
            throw ExitCode.failure
        }
    }
} 