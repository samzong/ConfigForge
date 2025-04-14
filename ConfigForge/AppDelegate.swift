//
//  AppDelegate.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation
import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    
    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 读取保存的语言设置
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        let currentLanguage = Locale.preferredLanguages.first?.prefix(2) ?? "en"
        
        // 检查语言设置是否已保存或与当前系统语言不同
        if savedLanguage == nil || savedLanguage != String(currentLanguage) {
            // 如果未设置或不匹配，使用当前系统语言作为默认值
            UserDefaults.standard.set(String(currentLanguage), forKey: "appLanguage")
        }
        
        // 设置应用的语言
        if let language = UserDefaults.standard.string(forKey: "appLanguage") {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
}
