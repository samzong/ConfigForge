import Foundation
import Yams // Make sure Yams is imported

// MARK: - KubeConfigParser Struct

struct KubeConfigParser {

    /// Decodes a KubeConfig object from a YAML string.
    /// - Parameter yamlString: The YAML string representation of the Kubeconfig.
    /// - Returns: A `Result` containing the decoded `KubeConfig` or a `ConfigForgeError`.
    func decode(from yamlString: String) -> Result<KubeConfig, ConfigForgeError> {
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
            return .failure(.kubeConfigParsingFailed(error.localizedDescription))
        }
    }

    /// Encodes a KubeConfig object into a YAML string.
    /// - Parameter config: The `KubeConfig` object to encode.
    /// - Returns: A `Result` containing the YAML string or a `ConfigForgeError`.
    func encode(config: KubeConfig) -> Result<String, ConfigForgeError> {
        // Configure encoder for readability
        let encoder = YAMLEncoder()
        do {
            let yamlString = try encoder.encode(config)
            return .success(yamlString)
        } catch {
            return .failure(.kubeConfigEncodingFailed(error.localizedDescription))
        }
    }
} 
