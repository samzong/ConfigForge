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