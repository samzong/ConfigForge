import SwiftUI
import UniformTypeIdentifiers
enum ConfigContentType: Sendable {
    case ssh
    case kubernetes
    case unknown 

    var utType: UTType {
        switch self {
        case .ssh: return .text 
        case .kubernetes: return .yaml 
        case .unknown: return .data
        }
    }

    var defaultFilenameExtension: String {
        switch self {
        case .ssh: return "txt" 
        case .kubernetes: return "yaml"
        case .unknown: return "dat"
        }
    }

    static func from(type: ConfigType) -> ConfigContentType {
        switch type {
        case .ssh: return .ssh
        case .kubernetes: return .kubernetes
        }
    }
}

struct ConfigDocument: FileDocument, Sendable {
    static let readableContentTypes: [UTType] = [.text, .yaml] 

    var content: String
    var contentType: ConfigContentType
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let stringContent = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = stringContent
        if configuration.contentType == .yaml || stringContent.contains("apiVersion:") {
            self.contentType = .kubernetes
        } else if configuration.contentType == .text {
            self.contentType = .ssh
        }
        else {
             self.contentType = .unknown
             print("Warning: Could not determine config type during read.")
        }

    }
    init(content: String, type: ConfigContentType) {
        self.content = content
        self.contentType = type
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown) 
        }
        return FileWrapper(regularFileWithContents: data)
    }
} 
