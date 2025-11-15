import Foundation
import Network
import Security

// MARK: - Android TV Key Codes

/// Android TV remote control key codes
/// Only including codes we actually use
enum KeyCode: UInt32 {
    case mediaPlayPause = 85
    case mediaPlay = 126
    case mediaPause = 127
    case mediaStop = 86
    case mediaNext = 87
    case mediaPrevious = 88
    case volumeUp = 24
    case volumeDown = 25
    case mute = 91
    case home = 3
    case back = 4
    case dpadUp = 19
    case dpadDown = 20
    case dpadLeft = 21
    case dpadRight = 22
    case dpadCenter = 23
}

// MARK: - Protocol Messages
// Note: Protocol message encoding moved to ProtobufEncoder.swift
// Use AndroidTVMessages class for creating protocol messages

// MARK: - Certificate Management

@available(macOS 13.0, *)
struct CertificateHelper {

    /// Generate a simple self-signed certificate using OpenSSL command
    static func generateSelfSignedCertificate() throws {
        let certPath = Configuration.certFileURL.path
        let keyPath = Configuration.keyFileURL.path
        let p12Path = Configuration.configDirectory.appendingPathComponent(".shield_cert.p12").path

        // Check if already exists
        if Configuration.hasCertificates() {
            return
        }

        print("Generating self-signed certificate...")

        // Generate private key
        let keyResult = shell("openssl genrsa -out \"\(keyPath)\" 2048 2>&1")
        guard keyResult.exitCode == 0 else {
            throw NSError(domain: "CertificateError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate private key: \(keyResult.output)"
            ])
        }

        // Generate self-signed certificate (non-interactive)
        let certResult = shell("""
            openssl req -new -x509 -key "\(keyPath)" -out "\(certPath)" -days 3650 \
            -subj "/C=US/ST=State/L=City/O=Org/CN=AndroidTV"
            """)
        guard certResult.exitCode == 0 else {
            throw NSError(domain: "CertificateError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate certificate: \(certResult.output)"
            ])
        }

        // Generate P12 file with simple password
        let p12Result = shell("""
            openssl pkcs12 -export -out "\(p12Path)" \
            -inkey "\(keyPath)" -in "\(certPath)" -passout pass:shield
            """)
        guard p12Result.exitCode == 0 else {
            throw NSError(domain: "CertificateError", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "Failed to generate P12: \(p12Result.output)"
            ])
        }

        print("✅ Certificate generated successfully")
    }

    /// Load identity (certificate + private key) from P12 file
    static func loadIdentity() throws -> SecIdentity {
        let p12Path = Configuration.configDirectory.appendingPathComponent(".shield_cert.p12").path
        let p12URL = URL(fileURLWithPath: p12Path)

        guard let p12Data = try? Data(contentsOf: p12URL) else {
            throw NSError(domain: "CertError", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "Failed to read P12 file"
            ])
        }

        // Import P12 with password
        let options: [String: Any] = [
            kSecImportExportPassphrase as String: "shield"
        ]

        var rawItems: CFArray?
        let status = SecPKCS12Import(p12Data as CFData, options as CFDictionary, &rawItems)

        guard status == errSecSuccess else {
            throw NSError(domain: "CertError", code: 2, userInfo: [
                NSLocalizedDescriptionKey: "Failed to import P12 file (status: \(status))"
            ])
        }

        guard let items = rawItems as? [[String: Any]],
              let firstItem = items.first,
              let identityRef = firstItem[kSecImportItemIdentity as String] else {
            throw NSError(domain: "CertError", code: 3, userInfo: [
                NSLocalizedDescriptionKey: "No identity found in P12 file"
            ])
        }

        return (identityRef as! SecIdentity)
    }
}

// MARK: - Helper for shell commands

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
