//
//  ConfigForgeApp.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

@main
struct ConfigForgeApp: App {
    // 添加 AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup(content: {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
        })
        .windowStyle(.hiddenTitleBar) // 可选：使用更现代的窗口样式
        .commands {
            // 添加菜单命令
            CommandGroup(replacing: .newItem) {
                Button(L10n.Sidebar.Add.host) {
                    NotificationCenter.default.post(name: NSNotification.Name("NewEntry"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
        }
    }
}
