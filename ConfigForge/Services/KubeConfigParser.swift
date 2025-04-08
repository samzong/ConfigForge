import Foundation
import Yams // Make sure Yams is imported

// MARK: - KubeConfigParserError Enum

enum KubeConfigParserError: Error, LocalizedError {
    case encodingFailed(Error)
    case decodingFailed(Error)
    case invalidInputString

    var errorDescription: String? {
        switch self {
        case .encodingFailed(let underlyingError):
            return "Kubeconfig 编码失败: \(underlyingError.localizedDescription)"
        case .decodingFailed(let underlyingError):
            // Yams errors can be detailed, provide useful info
            if let yamlError = underlyingError as? YamlError {
                return "Kubeconfig 解析失败: \(yamlError.localizedDescription)"
            }
            return "Kubeconfig 解析失败: \(underlyingError.localizedDescription)"
        case .invalidInputString:
            return "提供的 YAML 字符串无效或为空。"
        }
    }
}

// MARK: - KubeConfigParser Struct

struct KubeConfigParser {

    /// Decodes a KubeConfig object from a YAML string.
    /// - Parameter yamlString: The YAML string representation of the Kubeconfig.
    /// - Returns: A `Result` containing the decoded `KubeConfig` or a `KubeConfigParserError`.
    func decode(from yamlString: String) -> Result<KubeConfig, KubeConfigParserError> {
        guard !yamlString.isEmpty else {
            // Handle empty string case - often means an empty or non-existent file
            // Return an empty KubeConfig object rather than an error if desired,
            // but for parsing, an empty string is typically invalid input.
            // Alternatively, return a default empty KubeConfig:
             return .success(KubeConfig(apiVersion: nil, kind: nil, preferences: nil, clusters: [], contexts: [], users: [], currentContext: nil))
            // Or treat as error: return .failure(.invalidInputString)
        }

        let decoder = YAMLDecoder()
        do {
            let config = try decoder.decode(KubeConfig.self, from: yamlString)
            return .success(config)
        } catch {
            return .failure(.decodingFailed(error))
        }
    }

    /// Encodes a KubeConfig object into a YAML string.
    /// - Parameter config: The `KubeConfig` object to encode.
    /// - Returns: A `Result` containing the YAML string or a `KubeConfigParserError`.
    func encode(config: KubeConfig) -> Result<String, KubeConfigParserError> {
        // Configure encoder for readability
        let encoder = YAMLEncoder()
        do {
            let yamlString = try encoder.encode(config)
            return .success(yamlString)
        } catch {
            return .failure(.encodingFailed(error))
        }
    }
} 
