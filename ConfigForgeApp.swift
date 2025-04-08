import SwiftUI

@main
struct ConfigForgeApp: App {
    // Assuming MainViewModel might be needed globally or passed down
    // @StateObject var mainViewModel = MainViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                // .environmentObject(mainViewModel) // If using EnvironmentObject
        }
        // Add Commands for Menu Bar Items
        .commands {
            CommandGroup(after: .saveItem) { // Place after Save
                 Divider()
                 Button("备份 SSH 配置...") {
                     triggerSshBackup()
                 }
                 .keyboardShortcut("b", modifiers: [.command, .shift]) // Example shortcut

                 Button("恢复 SSH 配置...") {
                      triggerSshRestore()
                 }
                 .keyboardShortcut("r", modifiers: [.command, .shift]) // Example shortcut

                 // {{ modifications }}
                Divider() // Separate Kube commands

                Button("备份 Kubeconfig...") {
                    triggerKubeBackup()
                }
                .keyboardShortcut("k", modifiers: [.command, .option]) // Example shortcut for Kube
                 // Disable if not in Kubernetes mode (Requires access to ViewModel)
                 // .disabled(mainViewModel.selectedConfigurationType != .kubernetes)

                Button("恢复 Kubeconfig...") {
                     triggerKubeRestore()
                }
                .keyboardShortcut("j", modifiers: [.command, .option]) // Example shortcut for Kube
                 // Disable if not in Kubernetes mode
                 // .disabled(mainViewModel.selectedConfigurationType != .kubernetes)

            }
        }
    }

    // Helper functions to get the ViewModel instance from the active window scene
    // This is one way; EnvironmentObject or passing directly might be used instead.
    private func getViewModelFromActiveScene() -> MainViewModel? {
        // This is complex and depends on app structure.
        // A simpler approach might be to pass actions down or use EnvironmentObject.
        // For now, these trigger functions will just print, assuming direct access isn't trivial here.
        print("Attempting to find ViewModel - requires proper implementation based on app structure.")
        return nil // Placeholder
    }


    // Trigger functions (Placeholders - need proper ViewModel access)
    private func triggerSshBackup() {
        print("Trigger SSH Backup (Needs ViewModel access)")
        // Example: getViewModelFromActiveScene()?.backupSshConfig(to: <#URL from file exporter#>)
        // The actual file exporter logic is in ContentView, making direct triggering from here complex.
        // Consider using NotificationCenter or App Delegate pattern if not using EnvironmentObject.
         // For now, assume ContentView handles exporter presentation. Focus on adding menu item.
    }

    private func triggerSshRestore() {
        print("Trigger SSH Restore (Needs ViewModel access)")
        // Example: getViewModelFromActiveScene()?.restoreSshConfig(from: <#URL from file importer#>)
         // Assume ContentView handles importer presentation.
    }

    // {{ modifications }}
   private func triggerKubeBackup() {
       print("Trigger Kube Backup (Needs ViewModel access)")
       getViewModelFromActiveScene()?.backupKubeConfig() // Call placeholder method
   }

   private func triggerKubeRestore() {
       print("Trigger Kube Restore (Needs ViewModel access)")
       getViewModelFromActiveScene()?.restoreKubeConfig() // Call placeholder method
   }

} 