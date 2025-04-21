import Foundation

struct SSHConfigEntry {
    var host: String?
    var hostname: String?
    var user: String?
    var port: String?
    var identityFile: String?
    var forwardAgent: String?
    var proxyCommand: String?
    var serverAliveInterval: String?
    var serverAliveCountMax: String?
    var strictHostKeyChecking: String?
    var userKnownHostsFile: String?
    var connectTimeout: String?
    var otherOptions: [String: String] = [:]
    
    init(host: String? = nil, hostname: String? = nil, user: String? = nil, 
         port: String? = nil, identityFile: String? = nil, forwardAgent: String? = nil, 
         proxyCommand: String? = nil, serverAliveInterval: String? = nil, 
         serverAliveCountMax: String? = nil, strictHostKeyChecking: String? = nil, 
         userKnownHostsFile: String? = nil, connectTimeout: String? = nil, 
         otherOptions: [String: String] = [:]) {
        self.host = host
        self.hostname = hostname
        self.user = user
        self.port = port
        self.identityFile = identityFile
        self.forwardAgent = forwardAgent
        self.proxyCommand = proxyCommand
        self.serverAliveInterval = serverAliveInterval
        self.serverAliveCountMax = serverAliveCountMax
        self.strictHostKeyChecking = strictHostKeyChecking
        self.userKnownHostsFile = userKnownHostsFile
        self.connectTimeout = connectTimeout
        self.otherOptions = otherOptions
    }
} 