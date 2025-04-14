//
//  ErrorMessage.swift
//  ConfigForge
//
//  Created by samzong
//

import Foundation

// 添加一个可识别的错误消息结构体
struct ErrorMessage: Identifiable {
    let id = UUID()
    let message: String
} 