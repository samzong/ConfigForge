//
//  LocalizationManager.swift
//  ConfigForge
//
//  Created by samzong on 4/2/25.
//

import Foundation
import SwiftUI

/// 本地化工具类，用于提供本地化字符串
class LocalizationManager {
    
    /// 获取本地化字符串
    /// - Parameter key: 本地化键
    /// - Returns: 本地化后的字符串
    static func localizedString(for key: String) -> String {
        return NSLocalizedString(key, bundle: .main, comment: "")
    }
    
    /// 获取格式化的本地化字符串
    /// - Parameters:
    ///   - key: 本地化键
    ///   - arguments: 格式化参数
    /// - Returns: 格式化后的本地化字符串
    static func localizedString(for key: String, _ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(key, bundle: .main, comment: "")
        return String(format: format, arguments: arguments)
    }
}

/// 便捷访问本地化字符串的扩展
extension String {
    // Renamed to avoid conflict with other extensions
    var lfLocalized: String {
        return LocalizationManager.localizedString(for: self)
    }
    
    // Renamed to avoid conflict with other extensions
    func lfLocalized(_ arguments: CVarArg...) -> String {
        let format = NSLocalizedString(self, bundle: .main, comment: "")
        return String(format: format, arguments: arguments)
    }
}

/// 本地化文本视图
struct LocalizedText: View {
    let key: String
    let args: [CVarArg]
    
    init(_ key: String, _ args: CVarArg...) {
        self.key = key
        self.args = args
    }
    
    var body: some View {
        if args.isEmpty {
            Text(key.cfLocalized)
        } else {
            Text(key.cfLocalized(with: args))
        }
    }
} 