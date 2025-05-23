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
        let savedLanguage = UserDefaults.standard.string(forKey: "appLanguage")
        let currentLanguage = Locale.preferredLanguages.first?.prefix(2) ?? "en"

        if savedLanguage == nil || savedLanguage != String(currentLanguage) {
            UserDefaults.standard.set(String(currentLanguage), forKey: "appLanguage")
        }
        if let language = UserDefaults.standard.string(forKey: "appLanguage") {
            UserDefaults.standard.set([language], forKey: "AppleLanguages")
            UserDefaults.standard.synchronize()
        }
    }
}
