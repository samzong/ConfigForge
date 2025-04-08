import Foundation

// MARK: - KubeConfig Root Structure

// {{ modifications }}
// Make KubeConfig Equatable (requires nested types to be Equatable)
struct KubeConfig: Codable, Equatable {
    var apiVersion: String? // Use var if potentially mutable
    var kind: String?       // Use var if potentially mutable
    var preferences: [String: String]? // var for mutability
    var clusters: [KubeCluster]?       // var for mutability
    var contexts: [KubeContext]?       // var for mutability
    var users: [KubeUser]?           // var for mutability
    var currentContext: String?        // var for mutability

    enum CodingKeys: String, CodingKey {
        case apiVersion, kind, preferences, clusters, contexts, users
        case currentContext = "current-context"
    }

    // Equatable conformance
    static func == (lhs: KubeConfig, rhs: KubeConfig) -> Bool {
        return lhs.apiVersion == rhs.apiVersion &&
               lhs.kind == rhs.kind &&
               lhs.preferences == rhs.preferences &&
               lhs.clusters == rhs.clusters && // Relies on [KubeCluster]? being Equatable
               lhs.contexts == rhs.contexts && // Relies on [KubeContext]? being Equatable
               lhs.users == rhs.users &&       // Relies on [KubeUser]? being Equatable
               lhs.currentContext == rhs.currentContext
    }

    // Helper to get non-optional arrays for easier processing
    var safeClusters: [KubeCluster] { clusters ?? [] }
    var safeContexts: [KubeContext] { contexts ?? [] }
    var safeUsers: [KubeUser] { users ?? [] }
}

// MARK: - KubeCluster

// {{ modifications }}
// Make KubeCluster Equatable
struct KubeCluster: Codable, Identifiable, Equatable {
    var name: String // Use var if name might be editable later (though complex)
    var cluster: ClusterDetails // Use var

    var id: String { name }

    // Equatable conformance
    static func == (lhs: KubeCluster, rhs: KubeCluster) -> Bool {
        return lhs.name == rhs.name && lhs.cluster == rhs.cluster
    }
}

// {{ modifications }}
// Make ClusterDetails Equatable and properties mutable
struct ClusterDetails: Codable, Equatable {
    var server: String // Changed to var
    var certificateAuthorityData: String? // Changed to var
    var insecureSkipTlsVerify: Bool?    // Changed to var

    enum CodingKeys: String, CodingKey {
        case server
        case certificateAuthorityData = "certificate-authority-data"
        case insecureSkipTlsVerify = "insecure-skip-tls-verify"
    }

    // Equatable conformance
    static func == (lhs: ClusterDetails, rhs: ClusterDetails) -> Bool {
        return lhs.server == rhs.server &&
               lhs.certificateAuthorityData == rhs.certificateAuthorityData &&
               lhs.insecureSkipTlsVerify == rhs.insecureSkipTlsVerify
    }
}

// MARK: - KubeContext

// {{ modifications }}
// Make KubeContext Equatable
struct KubeContext: Codable, Identifiable, Equatable {
    var name: String // Use var if name might be editable later
    var context: ContextDetails // Use var

    var id: String { name }

    // Equatable conformance
    static func == (lhs: KubeContext, rhs: KubeContext) -> Bool {
        return lhs.name == rhs.name && lhs.context == rhs.context
    }
}

// {{ modifications }}
// Make ContextDetails Equatable and properties mutable
struct ContextDetails: Codable, Equatable {
    var cluster: String   // Changed to var
    var user: String      // Changed to var
    var namespace: String? // Changed to var

    // Equatable conformance
    static func == (lhs: ContextDetails, rhs: ContextDetails) -> Bool {
        return lhs.cluster == rhs.cluster &&
               lhs.user == rhs.user &&
               lhs.namespace == rhs.namespace
    }
}

// MARK: - KubeUser

// {{ modifications }}
// Make KubeUser Equatable
struct KubeUser: Codable, Identifiable, Equatable {
    var name: String // Use var if name might be editable later
    var user: UserDetails // Use var

    var id: String { name }

    // Equatable conformance
    static func == (lhs: KubeUser, rhs: KubeUser) -> Bool {
        return lhs.name == rhs.name && lhs.user == rhs.user
    }
}

// {{ modifications }}
// Make UserDetails Equatable and properties mutable
struct UserDetails: Codable, Equatable {
    var clientCertificateData: String? // Changed to var
    var clientKeyData: String?         // Changed to var
    var token: String?                 // Changed to var

    enum CodingKeys: String, CodingKey {
        case clientCertificateData = "client-certificate-data"
        case clientKeyData = "client-key-data"
        case token
    }

    // Equatable conformance
    static func == (lhs: UserDetails, rhs: UserDetails) -> Bool {
        return lhs.clientCertificateData == rhs.clientCertificateData &&
               lhs.clientKeyData == rhs.clientKeyData &&
               lhs.token == rhs.token
    }
} 