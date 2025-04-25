import Foundation
import Yams // Make sure Yams is imported

// MARK: - KubeConfigValidationError 枚举

/// 表示 Kubernetes 配置验证过程中可能出现的错误
enum KubeConfigValidationError: Error, LocalizedError {
    /// YAML 格式无效
    case invalidYAMLFormat(String)
    
    /// 缺少必要的字段
    case missingRequiredField(String)
    
    /// 配置结构无效
    case invalidStructure(String)
    
    /// 引用了不存在的集群
    case referencesNonExistentCluster(String)
    
    /// 引用了不存在的用户
    case referencesNonExistentUser(String)
    
    public var errorDescription: String? {
        switch self {
        case .invalidYAMLFormat(let details):
            return "YAML 格式无效: \(details)"
        case .missingRequiredField(let field):
            return "缺少必要字段: \(field)"
        case .invalidStructure(let details):
            return "配置结构无效: \(details)"
        case .referencesNonExistentCluster(let name):
            return "引用了不存在的集群: \(name)"
        case .referencesNonExistentUser(let name):
            return "引用了不存在的用户: \(name)"
        }
    }
}

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
    
    /// 验证 YAML 字符串是否是有效的 YAML 格式
    /// - Parameter yamlString: 要验证的 YAML 字符串
    /// - Returns: 验证结果，成功或错误信息
    func validateYAMLFormat(_ yamlString: String) -> Result<Void, KubeConfigValidationError> {
        guard !yamlString.isEmpty else {
            return .failure(.invalidYAMLFormat("YAML 字符串为空"))
        }
        
        do {
            // 尝试解析为任意 YAML 对象，只检查格式是否正确
            _ = try Yams.load(yaml: yamlString)
            return .success(())
        } catch {
            return .failure(.invalidYAMLFormat(error.localizedDescription))
        }
    }
    
    /// 验证 KubeConfig 对象的结构是否有效
    /// - Parameter config: 要验证的 KubeConfig 对象
    /// - Returns: 验证结果，成功或错误信息
    func validateKubeConfigStructure(_ config: KubeConfig) -> Result<Void, KubeConfigValidationError> {
        // 验证基本结构
        if config.apiVersion == nil {
            return .failure(.missingRequiredField("apiVersion"))
        }
        
        if config.kind == nil {
            return .failure(.missingRequiredField("kind"))
        }
        
        // 验证上下文引用的集群和用户是否存在
        let clusterNames = Set(config.safeClusters.map { $0.name })
        let userNames = Set(config.safeUsers.map { $0.name })
        
        for context in config.safeContexts {
            let clusterName = context.context.cluster
            if !clusterNames.contains(clusterName) {
                return .failure(.referencesNonExistentCluster(clusterName))
            }
            
            let userName = context.context.user
            if !userNames.contains(userName) {
                return .failure(.referencesNonExistentUser(userName))
            }
        }
        
        // 验证当前上下文是否有效
        if let currentContext = config.currentContext,
           !config.safeContexts.contains(where: { $0.name == currentContext }) {
            return .failure(.invalidStructure("当前上下文 '\(currentContext)' 不存在"))
        }
        
        return .success(())
    }
    
    /// 验证 YAML 字符串是否包含有效的 Kubernetes 配置
    /// - Parameter yamlString: 要验证的 YAML 字符串
    /// - Returns: 验证结果，成功返回解析后的配置，失败返回错误信息
    func validateConfig(from yamlString: String) -> Result<KubeConfig, Error> {
        // 首先验证 YAML 格式
        let formatResult = validateYAMLFormat(yamlString)
        switch formatResult {
        case .failure(let error):
            return .failure(error)
        case .success:
            // YAML 格式验证通过，继续解析为 KubeConfig
            let decodeResult = decode(from: yamlString)
            switch decodeResult {
            case .failure(let error):
                return .failure(error)
            case .success(let config):
                // 解析成功，验证配置结构
                let structureResult = validateKubeConfigStructure(config)
                switch structureResult {
                case .failure(let error):
                    return .failure(error)
                case .success:
                    // 所有验证通过
                    return .success(config)
                }
            }
        }
    }
} 
