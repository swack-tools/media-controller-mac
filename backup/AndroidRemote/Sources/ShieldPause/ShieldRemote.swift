import Foundation
import CryptoKit
import Security

enum ShieldRemoteError: LocalizedError {
    case connectionFailed(String)
    case pairingFailed(String)
    case commandFailed(String)
    case certificateError(String)

    var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Connection failed: \(message)"
        case .pairingFailed(let message):
            return "Pairing failed: \(message)"
        case .commandFailed(let message):
            return "Command failed: \(message)"
        case .certificateError(let message):
            return "Certificate error: \(message)"
        }
    }
}

@available(macOS 13.0, *)
struct ShieldRemote {

    /// Main entry point - execute the pause command
    static func execute(host: String?, forceRepair: Bool) async throws {
        // Load configuration
        var config = Configuration.load()

        // Determine host
        let shieldHost: String
        if let providedHost = host {
            shieldHost = providedHost
        } else if let savedHost = config.shieldHost {
            shieldHost = savedHost
        } else {
            shieldHost = Validators.promptForIPAddress()
            config.shieldHost = shieldHost
            try config.save()
            print("Saved IP address to .env")
        }

        print("Shield TV Host: \(shieldHost)")

        // Check if we need to pair
        let needsPairing = forceRepair || !Configuration.hasCertificates()

        if forceRepair {
            print("Force repair requested - deleting existing certificates")
            Configuration.deleteCertificates()
        }

        if needsPairing {
            print("Generating certificates and pairing...")
            try CertificateHelper.generateSelfSignedCertificate()

            // Perform pairing
            try await pair(host: shieldHost)

            // Save config
            config.shieldHost = shieldHost
            try config.save()
        }

        // Send play/pause command
        try await sendPlayPause(host: shieldHost)

        print("Done!")
    }

    /// Pair with Shield TV
    private static func pair(host: String) async throws {
        print("\nInitiating pairing with Shield at \(host)...")
        print("A PIN code should appear on your Shield TV screen.")

        let connection = AndroidTVConnection()

        do {
            // Connect to pairing port (6467)
            print("Connecting to \(host):6467...")
            try await connection.connect(host: host, port: 6467, useTLS: true)
            print("Connected!")

            // Send pairing request
            let pairingRequest = AndroidTVMessages.createPairingRequest(
                clientName: "Shield Pause CLI",
                serviceName: "Shield TV"
            )
            try await connection.sendMessage(pairingRequest)

            // Wait for pairing ACK response
            let _ = try await connection.receiveMessage()

            // Send options request
            let optionsRequest = AndroidTVMessages.createOptionsRequest()
            try await connection.sendMessage(optionsRequest)

            // Wait for options response
            let optionsResponse = try await connection.receiveMessage()

            // Parse encoding type from options response
            // Response format: ...a2 01 XX 12 04 08 YY 10 06...
            // We need to extract YY (the encoding type the Shield prefers)
            var encodingType: UInt8 = 0  // Default to hexadecimal
            if optionsResponse.count >= 13 {
                // Simple parsing: look for the pattern 0x12 0x04 0x08 [type]
                for i in 0..<(optionsResponse.count - 3) {
                    if optionsResponse[i] == 0x12 && optionsResponse[i+1] == 0x04 && optionsResponse[i+2] == 0x08 {
                        encodingType = optionsResponse[i+3]
                        break
                    }
                }
            }

            // Send configuration request with Shield's preferred encoding
            let configRequest = AndroidTVMessages.createConfigurationRequest(encodingType: encodingType)
            try await connection.sendMessage(configRequest)

            // Wait for configuration ACK
            let _ = try await connection.receiveMessage()

            // PIN should appear NOW (after configuration ACK)
            print("\n✅ A PIN code should now appear on your Shield TV screen")

            // Get PIN from user
            let pin = Validators.promptForPIN()

            // Create and send secret
            let secret = try createSecret(pin: pin, serverCertificate: connection.serverCertificate)
            let secretMessage = AndroidTVMessages.createSecretMessage(secret: secret)
            try await connection.sendMessage(secretMessage)

            // Wait for response
            let secretResponse = try await connection.receiveMessage()

            // Parse status from response
            // Response format: 08 02 10 [status_varint]
            // Field 1 (0x08): protocol_version = 2
            // Field 2 (0x10): status
            var status = 0
            var foundStatus = false

            // Look for field 2 (status) tag = 0x10
            for i in 0..<secretResponse.count {
                if secretResponse[i] == 0x10 && i + 1 < secretResponse.count {
                    // Found status field, decode varint
                    let byte1 = secretResponse[i + 1]
                    if byte1 & 0x80 != 0 && i + 2 < secretResponse.count {
                        // Multi-byte varint
                        let byte2 = secretResponse[i + 2]
                        status = Int(byte1 & 0x7F) | (Int(byte2) << 7)
                    } else {
                        // Single byte
                        status = Int(byte1)
                    }
                    foundStatus = true
                    break
                }
            }

            guard foundStatus else {
                throw ShieldRemoteError.pairingFailed("Could not parse secret response status")
            }

            if status == 200 {
                print("✅ Pairing successful!")
            } else {
                throw ShieldRemoteError.pairingFailed("PIN rejected by Shield (status \(status)). The secret hash did not match.")
            }

            connection.disconnect()

        } catch {
            connection.disconnect()
            throw ShieldRemoteError.pairingFailed(error.localizedDescription)
        }
    }

    /// Send play/pause command to Shield TV
    private static func sendPlayPause(host: String) async throws {
        print("Connecting to \(host):6466...")

        let connection = AndroidTVConnection()

        do {
            // Connect to remote port (6466)
            try await connection.connect(host: host, port: 6466, useTLS: true)
            print("Connected!")

            // Wait for Shield to send configuration message
            let _ = try await connection.receiveMessage()

            // Send proper RemoteConfigure response
            let configResponse = AndroidTVMessages.createRemoteConfigureMessage()
            try await connection.sendMessage(configResponse)

            // Receive remote_set_active message and respond
            do {
                let setActiveMsg = try await connection.receiveMessage()
                // Shield sends remote_set_active (field 2), we must respond with our active features
                if setActiveMsg.count > 0 && setActiveMsg[0] == 0x12 { // Field 2 = remote_set_active
                    let setActiveResponse = AndroidTVMessages.createRemoteSetActiveMessage()
                    try await connection.sendMessage(setActiveResponse)
                }
            } catch {
                // May not always send a follow-up
            }

            // Now send the key press
            print("Sending play/pause command...")
            let keyPress = AndroidTVMessages.createKeyPressMessage(
                keyCode: KeyCode.mediaPlayPause.rawValue
            )
            try await connection.sendMessage(keyPress)

            print("Command sent successfully!")

            // Small delay to ensure message is sent
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds

            connection.disconnect()

        } catch {
            connection.disconnect()
            throw ShieldRemoteError.commandFailed(error.localizedDescription)
        }
    }

    /// Create secret hash from PIN
    /// According to Android TV Remote Protocol v2 (working implementation):
    /// secret = SHA256(client_mod + client_exp + server_mod + server_exp + PIN[1:3])
    /// First byte of hash must match PIN[0]
    private static func createSecret(pin: String, serverCertificate: SecCertificate?) throws -> [UInt8] {
        // Convert PIN from hex string to 3 bytes
        // PIN "F7CE34" → [0xF7, 0xCE, 0x34]
        guard pin.count == 6,
              let pinData = Data(hexString: pin),
              pinData.count == 3 else {
            throw ShieldRemoteError.pairingFailed("Invalid PIN format - expected 6 hex characters")
        }

        let pinBytes = Array(pinData)
        let pinHashBytes = Data([pinBytes[1], pinBytes[2]])  // Use only bytes 2-3 in hash

        // Load client certificate
        let identity = try CertificateHelper.loadIdentity()

        var clientCert: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &clientCert)
        guard status == errSecSuccess, let cert = clientCert else {
            throw ShieldRemoteError.certificateError("Failed to extract certificate from identity")
        }

        guard let serverCert = serverCertificate else {
            throw ShieldRemoteError.pairingFailed("No server certificate available")
        }

        // Extract RSA public key components from both certificates
        let clientComponents = try extractRSAComponents(from: cert)
        let serverComponents = try extractRSAComponents(from: serverCert)

        // Build hash: client_mod + client_exp + server_mod + server_exp + PIN[1:3]
        var shaHash = SHA256()
        shaHash.update(data: clientComponents.modulus)
        shaHash.update(data: clientComponents.exponent)
        shaHash.update(data: serverComponents.modulus)
        shaHash.update(data: serverComponents.exponent)
        shaHash.update(data: pinHashBytes)

        return Array(shaHash.finalize())
    }

    /// Extract RSA public key modulus and exponent from certificate
    private static func extractRSAComponents(from certificate: SecCertificate) throws -> (modulus: Data, exponent: Data) {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw ShieldRemoteError.certificateError("Failed to extract public key from certificate")
        }

        // Export public key data
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            let err = error?.takeRetainedValue()
            throw ShieldRemoteError.certificateError("Failed to export public key: \(err?.localizedDescription ?? "unknown")")
        }

        // Parse RSA public key structure
        // Public key format is: Header + Modulus + Exponent
        // We need to extract the actual modulus and exponent bytes
        // Simplified extraction based on typical RSA key structure
        // For RSA keys, the data typically has:
        // - Some header bytes (8 bytes)
        // - Modulus (large number, ~256 bytes for 2048-bit key)
        // - Exponent (usually 3 bytes, often 0x010001 = 65537)

        // Extract modulus: skip first 8 bytes, take everything except last 5
        let modulusStart = 8
        let modulusEnd = keyData.count - 5
        guard modulusEnd > modulusStart else {
            throw ShieldRemoteError.certificateError("Public key data too small")
        }

        var modulus = keyData.subdata(in: modulusStart..<modulusEnd)

        // Remove leading null byte if present (for keys at exact byte boundary)
        if modulus.count >= 257 && modulus[0] == 0x00 {
            modulus = modulus.subdata(in: 1..<modulus.count)
        }

        // Extract exponent: last 3 bytes
        let exponent = keyData.subdata(in: (keyData.count - 3)..<keyData.count)

        return (modulus, exponent)
    }
}

// MARK: - Helper Extensions

extension Data {
    /// Create Data from a hex string
    init?(hexString: String) {
        let hexString = hexString.replacingOccurrences(of: " ", with: "")
        guard hexString.count % 2 == 0 else { return nil }

        var data = Data()
        var index = hexString.startIndex

        while index < hexString.endIndex {
            let nextIndex = hexString.index(index, offsetBy: 2)
            let byteString = hexString[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else { return nil }
            data.append(byte)
            index = nextIndex
        }

        self = data
    }
}
