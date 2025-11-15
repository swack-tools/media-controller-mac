import Foundation

struct Configuration {
    var shieldHost: String?

    static let envFileName = ".env"
    static let certFileName = ".shield_cert.pem"
    static let keyFileName = ".shield_key.pem"

    // Get the directory where the executable is located
    static var configDirectory: URL {
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    static var envFileURL: URL {
        configDirectory.appendingPathComponent(envFileName)
    }

    static var certFileURL: URL {
        configDirectory.appendingPathComponent(certFileName)
    }

    static var keyFileURL: URL {
        configDirectory.appendingPathComponent(keyFileName)
    }

    /// Load configuration from .env file
    static func load() -> Configuration {
        var config = Configuration()

        guard FileManager.default.fileExists(atPath: envFileURL.path) else {
            return config
        }

        do {
            let contents = try String(contentsOf: envFileURL, encoding: .utf8)
            let lines = contents.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Skip empty lines and comments
                guard !trimmed.isEmpty && !trimmed.hasPrefix("#") else {
                    continue
                }

                // Parse KEY=VALUE format
                let parts = trimmed.split(separator: "=", maxSplits: 1)
                guard parts.count == 2 else {
                    continue
                }

                let key = String(parts[0]).trimmingCharacters(in: .whitespaces)
                let value = String(parts[1]).trimmingCharacters(in: .whitespaces)

                if key == "SHIELD_HOST" {
                    config.shieldHost = value
                }
            }
        } catch {
            print("Warning: Could not read .env file: \(error.localizedDescription)")
        }

        return config
    }

    /// Save configuration to .env file
    func save() throws {
        var lines: [String] = []

        if let host = shieldHost {
            lines.append("SHIELD_HOST=\(host)")
        }

        let contents = lines.joined(separator: "\n") + "\n"
        try contents.write(to: Configuration.envFileURL, atomically: true, encoding: .utf8)
    }

    /// Check if certificate files exist
    static func hasCertificates() -> Bool {
        let certExists = FileManager.default.fileExists(atPath: certFileURL.path)
        let keyExists = FileManager.default.fileExists(atPath: keyFileURL.path)
        return certExists && keyExists
    }

    /// Read certificate data from file
    static func readCertificate() throws -> Data {
        return try Data(contentsOf: certFileURL)
    }

    /// Read private key data from file
    static func readPrivateKey() throws -> Data {
        return try Data(contentsOf: keyFileURL)
    }

    /// Save certificate data to file
    static func saveCertificate(_ data: Data) throws {
        try data.write(to: certFileURL, options: .atomic)
        print("Certificate saved to \(certFileName)")
    }

    /// Save private key data to file
    static func savePrivateKey(_ data: Data) throws {
        try data.write(to: keyFileURL, options: .atomic)
        print("Private key saved to \(keyFileName)")
    }

    /// Delete certificate files (used when forcing re-pairing)
    static func deleteCertificates() {
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: certFileURL.path) {
            try? fileManager.removeItem(at: certFileURL)
            print("Deleted \(certFileName)")
        }

        if fileManager.fileExists(atPath: keyFileURL.path) {
            try? fileManager.removeItem(at: keyFileURL)
            print("Deleted \(keyFileName)")
        }
    }
}
