//
//  LocalizationManager.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation
import SwiftUI
class LocalizationManager {
    static func localizedString(for key: String) -> String {
        return NSLocalizedString(key, bundle: .main, comment: "")
    }

    static func localizedString(for key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: .main, comment: "")
        return String(format: format, arguments: arguments)
    }
}

struct LocalizedText: View {
    let key: String
    let args: [CVarArg]

    init(_ key: String, _ args: CVarArg...) {
        self.key = key
        self.args = args
    }

    var body: some View {
        if args.isEmpty {
            let localizedString = NSLocalizedString(key, bundle: .main, comment: "")
            Text(localizedString)
        } else {
            let format = NSLocalizedString(key, bundle: .main, comment: "")
            Text(String(format: format, arguments: args))
        }
    }
} 