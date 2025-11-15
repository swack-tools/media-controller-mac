import Foundation
import Security

/// Secure storage for Shield TV TLS certificates using macOS Keychain
@available(macOS 13.0, *)
public class CertificateStore {
    private let service = "com.mediacontrol.shield"
    private let account = "shield-client-cert"
    private let password = "shield"

    public init() {}

    // MARK: - Public API

    /// Check if a certificate is stored in the Keychain
    public func hasCertificate() -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: false
        ]

        let status = SecItemCopyMatching(query as CFDictionary, nil)
        return status == errSecSuccess
    }

    /// Save P12 certificate data to Keychain
    public func saveCertificate(p12Data: Data) throws {
        // Delete existing certificate if present
        if hasCertificate() {
            try deleteCertificate()
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: p12Data,
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw CertificateStoreError.saveFailed("Keychain add failed: \(status)")
        }
    }

    /// Load SecIdentity from stored certificate
    public func loadIdentity() throws -> SecIdentity {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess, let p12Data = result as? Data else {
            throw CertificateStoreError.loadFailed("Certificate not found in Keychain")
        }

        // Import P12 data
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: password
        ]

        var rawItems: CFArray?
        let importStatus = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)

        guard importStatus == errSecSuccess else {
            throw CertificateStoreError.loadFailed("Failed to import P12 (status: \(importStatus))")
        }

        guard let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            throw CertificateStoreError.loadFailed("No identity found in P12")
        }

        // swiftlint:disable:next force_cast
        let identity = identityRef as! SecIdentity
        return identity
    }

    /// Delete certificate from Keychain
    public func deleteCertificate() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let status = SecItemDelete(query as CFDictionary)
        guard status == errSecSuccess || status == errSecItemNotFound else {
            throw CertificateStoreError.deleteFailed("Keychain delete failed: \(status)")
        }
    }

    /// Migrate existing certificate to have proper access control
    /// This updates certificates stored before the kSecAttrAccessible attribute was added
    public func migrateCertificateAccessControl() throws {
        guard hasCertificate() else {
            return // No certificate to migrate
        }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account
        ]

        let attributesToUpdate: [String: Any] = [
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributesToUpdate as CFDictionary)
        guard status == errSecSuccess else {
            throw CertificateStoreError.migrationFailed("Failed to update certificate attributes: \(status)")
        }
    }
}

// MARK: - Certificate Generation Helper

@available(macOS 13.0, *)
struct CertificateHelper {
    /// Generate a self-signed certificate and save to CertificateStore
    static func generateSelfSignedCertificate(store: CertificateStore) throws {
        // Create temporary directory for certificate generation
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }

        let certPath = tempDir.appendingPathComponent("cert.pem").path
        let keyPath = tempDir.appendingPathComponent("key.pem").path
        let p12Path = tempDir.appendingPathComponent("cert.p12").path

        // Generate private key
        let keyResult = shell("openssl genrsa -out \"\(keyPath)\" 2048 2>&1")
        guard keyResult.exitCode == 0 else {
            throw CertificateStoreError.generationFailed("Failed to generate private key: \(keyResult.output)")
        }

        // Generate self-signed certificate
        let certResult = shell("""
            openssl req -new -x509 -key "\(keyPath)" -out "\(certPath)" -days 3650 \
            -subj "/C=US/ST=State/L=City/O=MediaControl/CN=ShieldTV"
            """)
        guard certResult.exitCode == 0 else {
            throw CertificateStoreError.generationFailed("Failed to generate certificate: \(certResult.output)")
        }

        // Generate P12 file
        let p12Result = shell("""
            openssl pkcs12 -export -out "\(p12Path)" \
            -inkey "\(keyPath)" -in "\(certPath)" -passout pass:shield
            """)
        guard p12Result.exitCode == 0 else {
            throw CertificateStoreError.generationFailed("Failed to generate P12: \(p12Result.output)")
        }

        // Read P12 data and save to Keychain
        guard let p12Data = try? Data(contentsOf: URL(fileURLWithPath: p12Path)) else {
            throw CertificateStoreError.generationFailed("Failed to read P12 file")
        }

        try store.saveCertificate(p12Data: p12Data)
    }
}

// MARK: - Errors

public enum CertificateStoreError: LocalizedError {
    case saveFailed(String)
    case loadFailed(String)
    case deleteFailed(String)
    case generationFailed(String)
    case migrationFailed(String)

    public var errorDescription: String? {
        switch self {
        case .saveFailed(let msg):
            return "Failed to save certificate: \(msg)"
        case .loadFailed(let msg):
            return "Failed to load certificate: \(msg)"
        case .deleteFailed(let msg):
            return "Failed to delete certificate: \(msg)"
        case .generationFailed(let msg):
            return "Failed to generate certificate: \(msg)"
        case .migrationFailed(let msg):
            return "Failed to migrate certificate: \(msg)"
        }
    }
}

// MARK: - Shell Helper

private struct ShellResult {
    let output: String
    let exitCode: Int32
}

private func shell(_ command: String) -> ShellResult {
    let task = Process()
    let pipe = Pipe()

    task.standardOutput = pipe
    task.standardError = pipe
    task.arguments = ["-c", command]
    task.executableURL = URL(fileURLWithPath: "/bin/bash")
    task.standardInput = nil

    do {
        try task.run()
        task.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(data: data, encoding: .utf8) ?? ""

        return ShellResult(output: output, exitCode: task.terminationStatus)
    } catch {
        return ShellResult(output: error.localizedDescription, exitCode: -1)
    }
}
