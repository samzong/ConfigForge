import Foundation

struct KubeConfig: Codable {
    var apiVersion: String
    var kind: String
    var clusters: [KubeCluster]
    var contexts: [KubeContext]
    var users: [KubeUser]
    var currentContext: String?
    var preferences: [String: String]?
    
    enum CodingKeys: String, CodingKey {
        case apiVersion = "apiVersion"
        case kind = "kind"
        case clusters = "clusters"
        case contexts = "contexts"
        case users = "users"
        case currentContext = "current-context"
        case preferences = "preferences"
    }
}

struct KubeCluster: Codable {
    var name: String
    var cluster: ClusterData
}

struct ClusterData: Codable {
    var server: String
    var certificateAuthorityData: String?
    var insecureSkipTLSVerify: Bool?
    
    enum CodingKeys: String, CodingKey {
        case server = "server"
        case certificateAuthorityData = "certificate-authority-data"
        case insecureSkipTLSVerify = "insecure-skip-tls-verify"
    }
}

struct KubeContext: Codable {
    var name: String
    var context: ContextData
}

struct ContextData: Codable {
    var cluster: String?
    var user: String?
    var namespace: String?
}

struct KubeUser: Codable {
    var name: String
    var user: UserData
}

struct UserData: Codable {
    var clientCertificateData: String?
    var clientKeyData: String?
    var token: String?
    var username: String?
    var password: String?
    var authProvider: AuthProvider?
    var exec: ExecConfig?
    
    enum CodingKeys: String, CodingKey {
        case clientCertificateData = "client-certificate-data"
        case clientKeyData = "client-key-data"
        case token = "token"
        case username = "username"
        case password = "password"
        case authProvider = "auth-provider"
        case exec = "exec"
    }
}

struct AuthProvider: Codable {
    var name: String
    var config: [String: String]?
}

struct ExecConfig: Codable {
    var command: String
    var args: [String]?
    var env: [ExecEnv]?
    var apiVersion: String?
    
    enum CodingKeys: String, CodingKey {
        case command = "command"
        case args = "args"
        case env = "env"
        case apiVersion = "apiVersion"
    }
}

struct ExecEnv: Codable {
    var name: String
    var value: String
} 