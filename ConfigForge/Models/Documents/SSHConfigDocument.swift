//
//  SSHConfigDocument.swift
//  ConfigForge
//
//  Created by samzong
//

import SwiftUI
import UniformTypeIdentifiers

// 为文件导出器创建一个文档类型
struct SSHConfigDocument: FileDocument, Sendable {
    static let readableContentTypes: [UTType] = [.text]
    
    var configContent: String
    
    init(configContent: String) {
        self.configContent = configContent
    }
    
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let content = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        configContent = content
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        let data = configContent.data(using: .utf8)!
        return FileWrapper(regularFileWithContents: data)
    }
} 