import ArgumentParser
import Foundation

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open ConfigForge GUI application",
        discussion: "Launch the ConfigForge graphical user interface application",
        aliases: ["o"]
    )
    
    @Flag(name: .shortAndLong, help: "Run application in background without waiting for it to exit")
    var background = false
    
    @Flag(name: .shortAndLong, help: "Enable verbose output")
    var verbose = false
    
    func run() throws {
        let isVerbose = verbose || GlobalOptions.verbose
        
        if isVerbose {
            print("Launching ConfigForge GUI application...")
        }
        
        let appService = AppLauncherService()
        
        do {
            try appService.launchConfigForgeApp(background: background, verbose: isVerbose)
        } catch {
            if let appError = error as? AppLauncherError {
                print("Error: \(appError.localizedDescription)")
            } else {
                print("Error: Failed to launch ConfigForge application - \(error.localizedDescription)")
            }
            throw ExitCode.failure
        }
    }
}

// MARK: - App Launcher Service

class AppLauncherService {
    
    /// Launch the ConfigForge GUI application
    func launchConfigForgeApp(background: Bool, verbose: Bool) throws {
        let possibleAppPaths = getPossibleAppPaths()
        
        // Try to find the app
        guard let appPath = findConfigForgeApp(paths: possibleAppPaths, verbose: verbose) else {
            throw AppLauncherError.appNotFound(searchPaths: possibleAppPaths)
        }
        
        if verbose {
            print("Found ConfigForge.app at: \(appPath)")
        }
        
        // Launch the application
        try launchApp(at: appPath, background: background, verbose: verbose)
    }
    
    private func getPossibleAppPaths() -> [String] {
        return [
            "/Applications/ConfigForge.app",                    // Standard installation
            NSHomeDirectory() + "/Applications/ConfigForge.app", // User Applications folder
            "./ConfigForge.app",                                // Current directory (development)
            "../ConfigForge.app",                               // Parent directory (development)
            Bundle.main.bundlePath + "/../ConfigForge.app",     // Near CLI binary (development)
        ]
    }
    
    private func findConfigForgeApp(paths: [String], verbose: Bool) -> String? {
        let fileManager = FileManager.default
        
        for path in paths {
            if verbose {
                print("Checking path: \(path)")
            }
            
            if fileManager.fileExists(atPath: path) {
                // Verify it's actually a valid app bundle
                let infoPlistPath = path + "/Contents/Info.plist"
                if fileManager.fileExists(atPath: infoPlistPath) {
                    if verbose {
                        print("✓ Valid app bundle found at: \(path)")
                    }
                    return path
                } else if verbose {
                    print("✗ Invalid app bundle (no Info.plist): \(path)")
                }
            } else if verbose {
                print("✗ Not found: \(path)")
            }
        }
        
        return nil
    }
    
    private func launchApp(at appPath: String, background: Bool, verbose: Bool) throws {
        if background {
            // Launch in background using NSWorkspace (if available) or open command
            try launchAppInBackground(at: appPath, verbose: verbose)
        } else {
            // Launch and wait for the application to exit
            try launchAppAndWait(at: appPath, verbose: verbose)
        }
    }
    
    private func launchAppInBackground(at appPath: String, verbose: Bool) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appPath]
        
        // Redirect outputs to null to run silently in background
        if !verbose {
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice
        }
        
        if verbose {
            print("Executing: open -a \"\(appPath)\"")
        }
        
        do {
            try task.run()
            
            if verbose {
                print("ConfigForge application launched in background")
            } else {
                print("ConfigForge application launched")
            }
        } catch {
            throw AppLauncherError.launchFailed(error: error)
        }
    }
    
    private func launchAppAndWait(at appPath: String, verbose: Bool) throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-W", "-a", appPath] // -W flag makes open wait for the app to exit
        
        if verbose {
            print("Executing: open -W -a \"\(appPath)\"")
            print("Waiting for ConfigForge application to exit...")
        }
        
        do {
            try task.run()
            task.waitUntilExit()
            
            let exitCode = task.terminationStatus
            if verbose {
                print("ConfigForge application exited with code: \(exitCode)")
            }
        } catch {
            throw AppLauncherError.launchFailed(error: error)
        }
    }
}

// MARK: - Error Types

enum AppLauncherError: LocalizedError {
    case appNotFound(searchPaths: [String])
    case launchFailed(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .appNotFound(let paths):
            return "ConfigForge.app not found. Searched in:\n" + 
                paths.map { "  - \($0)" }.joined(separator: "\n") + 
                "\n\nPlease install ConfigForge or run from the correct directory."
        case .launchFailed(let error):
            return "Failed to launch ConfigForge application: \(error.localizedDescription)"
        }
    }
}