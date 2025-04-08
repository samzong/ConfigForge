import SwiftUI
import UniformTypeIdentifiers

// Enum to represent the type of configuration content
enum ConfigContentType: Sendable {
    case ssh
    case kubernetes
    case unknown // Fallback

    var utType: UTType {
        switch self {
        case .ssh: return .text // Or a custom UTType if defined
        case .kubernetes: return .yaml // Kubeconfig is typically YAML
        case .unknown: return .data
        }
    }

    var defaultFilenameExtension: String {
        switch self {
        case .ssh: return "txt" // SSH config usually has no extension or is txt
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
    static let readableContentTypes: [UTType] = [.text, .yaml] // Accept both text and YAML

    var content: String
    var contentType: ConfigContentType

    // Initialize from file content during import
    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let stringContent = String(data: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        self.content = stringContent

        // Attempt to determine type based on content or UTType
        if configuration.contentType == .yaml || stringContent.contains("apiVersion:") {
            self.contentType = .kubernetes
        } else if configuration.contentType == .text {
            // Could potentially be SSH config, but might need better heuristic
            // For now, assume text means SSH if not clearly Kube
            // A robust solution might require user confirmation or smarter parsing
            self.contentType = .ssh
        }
        else {
             self.contentType = .unknown
             // Optionally throw an error if type cannot be determined
             // throw CocoaError(.fileReadUnknown)
             print("Warning: Could not determine config type during read.")
        }

    }

    // Initialize explicitly for export
    init(content: String, type: ConfigContentType) {
        self.content = content
        self.contentType = type
    }

    // Create file wrapper for saving/exporting
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        guard let data = content.data(using: .utf8) else {
            throw CocoaError(.fileWriteUnknown) // Or a more specific error
        }
        return FileWrapper(regularFileWithContents: data)
    }
} 
