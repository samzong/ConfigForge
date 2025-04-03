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
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 读取保存的语言设置
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        
        // 如果有保存的语言设置，尝试切换
        if let language = savedLanguage, language != Bundle.main.preferredLocalizations.first {
            // 设置应用程序的语言
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
} 