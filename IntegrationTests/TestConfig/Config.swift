import Foundation

struct Config: Codable {
    let `default`: ConfigItem
}

struct ConfigItem: Codable {
    let host: String
    let port: Int
    let username: String
    let authentication: PrivateKeyAuthentication // can we do Authentication instead?
    let tunnels: [Tunnel]
}

protocol Authentication {
    
}

struct PrivateKeyAuthentication: Authentication, Codable {
    let privateKeyFile: String
    let passphrase: String
    
    var privateKeyURL: URL {
        if privateKeyFile.first == "/" {
            return URL(fileURLWithPath: privateKeyFile)
        } else {
            let testPath = URL(fileURLWithPath: #file).deletingLastPathComponent().path
            let filePath = "\(testPath)/../\(privateKeyFile)"
            return URL(fileURLWithPath: filePath)
        }
    }
}

struct PasswordAuthentication: Authentication, Codable {
    let password: String
}

struct Tunnel: Codable {
    let host: String
    let port: Int
}
