//
//  ConfigForgeApp.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import SwiftUI

@main
struct ConfigForgeApp: App {
    // 添加语言切换状态
    @AppStorage("appLanguage") private var appLanguage: String = Bundle.main.preferredLocalizations.first ?? "en"
    
    // 添加 AppDelegate
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 800, minHeight: 600)
                .onReceive(NotificationCenter.default.publisher(for: NSLocale.currentLocaleDidChangeNotification)) { _ in
                    // 当系统语言变化时，更新应用内语言设置
                    appLanguage = Bundle.main.preferredLocalizations.first ?? "en"
                }
        }
        .windowStyle(.hiddenTitleBar) // 可选：使用更现代的窗口样式
        .commands {
            // 添加菜单命令
            CommandGroup(replacing: .newItem) {
                Button("sidebar.add.host".cfLocalized) {
                    NotificationCenter.default.post(name: NSNotification.Name("NewEntry"), object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)
            }
            
            // 添加语言切换菜单
            CommandMenu("app.language".cfLocalized) {
                Button("app.language.english".cfLocalized) {
                    appLanguage = "en"
                    restartAppAlert()
                }
                
                Button("app.language.chinese".cfLocalized) {
                    appLanguage = "zh"
                    restartAppAlert()
                }
            }
        }
    }
    
    // 提示用户重启应用以应用语言更改
    private func restartAppAlert() {
        let alert = NSAlert()
        alert.messageText = "app.language.restart.title".cfLocalized
        alert.informativeText = "app.language.restart.message".cfLocalized
        alert.addButton(withTitle: "app.confirm".cfLocalized)
        alert.runModal()
    }
}
