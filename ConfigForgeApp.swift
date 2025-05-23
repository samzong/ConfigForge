import SwiftUI

@main
struct ConfigForgeApp: App {

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .commands {
            CommandGroup(after: .saveItem) { 
                 Divider()
                 Button("Backup SSH configuration...") {
                     triggerSshBackup()
                 }
                 .keyboardShortcut("b", modifiers: [.command, .shift]) 

                 Button("Restore SSH configuration...") {
                      triggerSshRestore()
                 }
                 .keyboardShortcut("r", modifiers: [.command, .shift]) 
                 Divider() 

                Button("Backup Kubeconfig...") {
                    triggerKubeBackup()
                }
                .keyboardShortcut("k", modifiers: [.command, .option]) 
                Button("Restore Kubeconfig...") {
                     triggerKubeRestore()
                }
                .keyboardShortcut("j", modifiers: [.command, .option]) 
            }
        }
    }
    private func getViewModelFromActiveScene() -> MainViewModel? {
        print("Attempting to find ViewModel - requires proper implementation based on app structure.")
        return nil 
    }
    private func triggerSshBackup() {
        print("Trigger SSH Backup (Needs ViewModel access)")
    }

    private func triggerSshRestore() {
        print("Trigger SSH Restore (Needs ViewModel access)")
    }
   private func triggerKubeBackup() {
       print("Trigger Kube Backup (Needs ViewModel access)")
       getViewModelFromActiveScene()?.backupKubeConfig() 
   }

   private func triggerKubeRestore() {
       print("Trigger Kube Restore (Needs ViewModel access)")
       getViewModelFromActiveScene()?.restoreKubeConfig() 
   }
} 