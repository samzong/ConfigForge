import Foundation

class CLITerminalService {
    func connectToSSHHost(host: String) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/ssh")
        task.arguments = [host]
        
        // Redirect standard input/output to this process
        task.standardInput = FileHandle.standardInput
        task.standardOutput = FileHandle.standardOutput
        task.standardError = FileHandle.standardError
        
        do {
            try task.run()
            // The connection is interactive, so we'll exit our program
            // and let SSH take over the terminal
            exit(0)
        } catch {
            throw NSError(domain: "CLITerminalService", code: 1, 
                         userInfo: [NSLocalizedDescriptionKey: "Failed to connect to SSH host: \(error.localizedDescription)"])
        }
    }
} 