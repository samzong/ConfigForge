import ArgumentParser
import Foundation

struct OpenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "open",
        abstract: "Open ConfigForge GUI application",
        discussion: "Launch the ConfigForge graphical user interface application",
        aliases: ["o"]
    )
    
    func run() throws {
        let appService = AppLauncherService()
        
        do {
            try appService.launchConfigForgeApp()
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
    private let appPath = "/Applications/ConfigForge.app"
    
    /// Launch the ConfigForge GUI application
    func launchConfigForgeApp() throws {
        // Check if app exists
        guard FileManager.default.fileExists(atPath: appPath) else {
            throw AppLauncherError.appNotFound
        }
        
        // Launch the application in background
        try launchApp()
    }
    
    private func launchApp() throws {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        task.arguments = ["-a", appPath]
        
        // Redirect outputs to null to run silently in background
        task.standardOutput = FileHandle.nullDevice
        task.standardError = FileHandle.nullDevice
        
        do {
            try task.run()
        } catch {
            throw AppLauncherError.launchFailed(error: error)
        }
    }
}

// MARK: - Error Types

enum AppLauncherError: LocalizedError {
    case appNotFound
    case launchFailed(error: Error)
    
    var errorDescription: String? {
        switch self {
        case .appNotFound:
            return "ConfigForge.app not found at /Applications/ConfigForge.app. Please install ConfigForge first."
        case .launchFailed(let error):
            return "Failed to launch ConfigForge application: \(error.localizedDescription)"
        }
    }
}