import Foundation

class CLIKubeConfigFileManager {
    private let fileManager = FileManager.default
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    
    private var kubeConfigPath: String {
        let kubeConfigEnv = ProcessInfo.processInfo.environment["KUBECONFIG"]
        if let path = kubeConfigEnv, !path.isEmpty, fileManager.fileExists(atPath: path) {
            return path
        }
        return NSHomeDirectory() + "/.kube/config"
    }
    
    func getKubeConfig() throws -> KubeConfig {
        let yamlData = try readConfigFile()
        return try parseYAML(yaml: yamlData)
    }
    
    func switchContext(to contextName: String) throws {
        var kubeConfig = try getKubeConfig()
        
        guard kubeConfig.contexts.contains(where: { $0.name == contextName }) else {
            throw NSError(domain: "CLIKubeConfigFileManager", code: 2,
                          userInfo: [NSLocalizedDescriptionKey: "Context '\(contextName)' not found"])
        }
        
        kubeConfig.currentContext = contextName
        try writeConfig(kubeConfig: kubeConfig)
    }
    
    private func readConfigFile() throws -> String {
        if !fileManager.fileExists(atPath: kubeConfigPath) {
            throw NSError(domain: "CLIKubeConfigFileManager", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Kubernetes config file does not exist at \(kubeConfigPath)"])
        }
        
        return try String(contentsOfFile: kubeConfigPath, encoding: .utf8)
    }
    
    private func writeConfig(kubeConfig: KubeConfig) throws {
        // This is a simplified implementation. In a real-world scenario,
        // we would need to properly serialize back to YAML and preserve comments.
        // For this demo, we're using a simple approach.
        
        let yamlString = """
        apiVersion: \(kubeConfig.apiVersion)
        kind: \(kubeConfig.kind)
        current-context: \(kubeConfig.currentContext ?? "")
        
        clusters:
        \(serializeClusters(kubeConfig.clusters))
        
        contexts:
        \(serializeContexts(kubeConfig.contexts))
        
        users:
        \(serializeUsers(kubeConfig.users))
        """
        
        try yamlString.write(toFile: kubeConfigPath, atomically: true, encoding: .utf8)
    }
    
    private func serializeClusters(_ clusters: [KubeCluster]) -> String {
        var result = ""
        for cluster in clusters {
            result += "- name: \(cluster.name)\n"
            result += "  cluster:\n"
            result += "    server: \(cluster.cluster.server)\n"
            if let certData = cluster.cluster.certificateAuthorityData {
                result += "    certificate-authority-data: \(certData)\n"
            }
            if let skipTLS = cluster.cluster.insecureSkipTLSVerify, skipTLS {
                result += "    insecure-skip-tls-verify: true\n"
            }
        }
        return result
    }
    
    private func serializeContexts(_ contexts: [KubeContext]) -> String {
        var result = ""
        for context in contexts {
            result += "- name: \(context.name)\n"
            result += "  context:\n"
            if let cluster = context.context.cluster {
                result += "    cluster: \(cluster)\n"
            }
            if let user = context.context.user {
                result += "    user: \(user)\n"
            }
            if let namespace = context.context.namespace {
                result += "    namespace: \(namespace)\n"
            }
        }
        return result
    }
    
    private func serializeUsers(_ users: [KubeUser]) -> String {
        var result = ""
        for user in users {
            result += "- name: \(user.name)\n"
            result += "  user:\n"
            if let certData = user.user.clientCertificateData {
                result += "    client-certificate-data: \(certData)\n"
            }
            if let keyData = user.user.clientKeyData {
                result += "    client-key-data: \(keyData)\n"
            }
            if let token = user.user.token {
                result += "    token: \(token)\n"
            }
            if let username = user.user.username {
                result += "    username: \(username)\n"
            }
            if let password = user.user.password {
                result += "    password: \(password)\n"
            }
            // Auth provider and exec are more complex and would need special handling
        }
        return result
    }
    
    private func parseYAML(yaml: String) throws -> KubeConfig {
        // For a production app, we'd use a proper YAML parser like Yams
        // This is a simplified implementation for demo purposes
        
        // Create a mock KubeConfig from the YAML string
        // In a real implementation, this would properly parse the YAML
        
        let currentContext = extractValue(from: yaml, forKey: "current-context")
        
        // Extract clusters section
        let clustersSection = extractSection(from: yaml, sectionName: "clusters")
        let clusters = parseClusterSection(clustersSection)
        
        // Extract contexts section
        let contextsSection = extractSection(from: yaml, sectionName: "contexts")
        let contexts = parseContextSection(contextsSection)
        
        // Extract users section
        let usersSection = extractSection(from: yaml, sectionName: "users")
        let users = parseUserSection(usersSection)
        
        return KubeConfig(
            apiVersion: "v1",
            kind: "Config",
            clusters: clusters,
            contexts: contexts,
            users: users,
            currentContext: currentContext,
            preferences: nil
        )
    }
    
    private func extractValue(from yaml: String, forKey key: String) -> String? {
        let lines = yaml.components(separatedBy: .newlines)
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            if trimmedLine.hasPrefix(key + ":") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    return components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        return nil
    }
    
    private func extractSection(from yaml: String, sectionName: String) -> String {
        var inSection = false
        var sectionContent = ""
        let lines = yaml.components(separatedBy: .newlines)
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine == sectionName + ":" {
                inSection = true
                continue
            }
            
            if inSection {
                // Check if we've moved to a new top-level section
                if !trimmedLine.isEmpty && !trimmedLine.hasPrefix("-") && !trimmedLine.hasPrefix(" ") && trimmedLine.contains(":") {
                    let components = trimmedLine.components(separatedBy: ":")
                    if components.count > 0 && !components[0].contains(" ") {
                        break
                    }
                }
                
                sectionContent += line + "\n"
            }
        }
        
        return sectionContent
    }
    
    private func parseClusterSection(_ section: String) -> [KubeCluster] {
        var clusters: [KubeCluster] = []
        let lines = section.components(separatedBy: .newlines)
        
        var currentName: String?
        var currentServer: String?
        var currentCertData: String?
        var currentSkipTLS: Bool?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("- name:") {
                // Save previous cluster if exists
                if let name = currentName, let server = currentServer {
                    let clusterData = ClusterData(
                        server: server,
                        certificateAuthorityData: currentCertData,
                        insecureSkipTLSVerify: currentSkipTLS
                    )
                    clusters.append(KubeCluster(name: name, cluster: clusterData))
                }
                
                // Start new cluster
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentName = components[1].trimmingCharacters(in: .whitespaces)
                    currentServer = nil
                    currentCertData = nil
                    currentSkipTLS = nil
                }
            } else if trimmedLine.hasPrefix("server:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentServer = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("certificate-authority-data:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentCertData = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("insecure-skip-tls-verify:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    let value = components[1].trimmingCharacters(in: .whitespaces)
                    currentSkipTLS = value == "true"
                }
            }
        }
        
        // Add the last cluster
        if let name = currentName, let server = currentServer {
            let clusterData = ClusterData(
                server: server,
                certificateAuthorityData: currentCertData,
                insecureSkipTLSVerify: currentSkipTLS
            )
            clusters.append(KubeCluster(name: name, cluster: clusterData))
        }
        
        return clusters
    }
    
    private func parseContextSection(_ section: String) -> [KubeContext] {
        var contexts: [KubeContext] = []
        let lines = section.components(separatedBy: .newlines)
        
        var currentName: String?
        var currentCluster: String?
        var currentUser: String?
        var currentNamespace: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("- name:") {
                // Save previous context if exists
                if let name = currentName {
                    let contextData = ContextData(
                        cluster: currentCluster,
                        user: currentUser,
                        namespace: currentNamespace
                    )
                    contexts.append(KubeContext(name: name, context: contextData))
                }
                
                // Start new context
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentName = components[1].trimmingCharacters(in: .whitespaces)
                    currentCluster = nil
                    currentUser = nil
                    currentNamespace = nil
                }
            } else if trimmedLine.hasPrefix("cluster:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentCluster = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("user:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentUser = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("namespace:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentNamespace = components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Add the last context
        if let name = currentName {
            let contextData = ContextData(
                cluster: currentCluster,
                user: currentUser,
                namespace: currentNamespace
            )
            contexts.append(KubeContext(name: name, context: contextData))
        }
        
        return contexts
    }
    
    private func parseUserSection(_ section: String) -> [KubeUser] {
        var users: [KubeUser] = []
        let lines = section.components(separatedBy: .newlines)
        
        var currentName: String?
        var currentCertData: String?
        var currentKeyData: String?
        var currentToken: String?
        var currentUsername: String?
        var currentPassword: String?
        
        for line in lines {
            let trimmedLine = line.trimmingCharacters(in: .whitespaces)
            
            if trimmedLine.hasPrefix("- name:") {
                // Save previous user if exists
                if let name = currentName {
                    let userData = UserData(
                        clientCertificateData: currentCertData,
                        clientKeyData: currentKeyData,
                        token: currentToken,
                        username: currentUsername,
                        password: currentPassword,
                        authProvider: nil,
                        exec: nil
                    )
                    users.append(KubeUser(name: name, user: userData))
                }
                
                // Start new user
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentName = components[1].trimmingCharacters(in: .whitespaces)
                    currentCertData = nil
                    currentKeyData = nil
                    currentToken = nil
                    currentUsername = nil
                    currentPassword = nil
                }
            } else if trimmedLine.hasPrefix("client-certificate-data:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentCertData = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("client-key-data:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentKeyData = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("token:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentToken = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("username:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentUsername = components[1].trimmingCharacters(in: .whitespaces)
                }
            } else if trimmedLine.hasPrefix("password:") {
                let components = trimmedLine.components(separatedBy: ":")
                if components.count > 1 {
                    currentPassword = components[1].trimmingCharacters(in: .whitespaces)
                }
            }
        }
        
        // Add the last user
        if let name = currentName {
            let userData = UserData(
                clientCertificateData: currentCertData,
                clientKeyData: currentKeyData,
                token: currentToken,
                username: currentUsername,
                password: currentPassword,
                authProvider: nil,
                exec: nil
            )
            users.append(KubeUser(name: name, user: userData))
        }
        
        return users
    }
} 