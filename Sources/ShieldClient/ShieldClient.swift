import Foundation

/// Public API for controlling Shield TV via Android TV Remote Protocol v2
@available(macOS 13.0, *)
public class ShieldClient {
    private let host: String
    private let certificateStore: CertificateStore

    public init(host: String, certificateStore: CertificateStore) {
        self.host = host
        self.certificateStore = certificateStore
    }

    // MARK: - Public API

    /// Check if this client is paired with the Shield TV
    public var isPaired: Bool {
        certificateStore.hasCertificate()
    }

    /// Pair with Shield TV - prompts for PIN via callback when ready
    /// - Parameter pinProvider: Async closure called when PIN appears on TV, should return the 6-character hex PIN
    /// - Throws: ShieldClientError if pairing fails
    public func pair(pinProvider: () async throws -> String) async throws {
        // Generate certificates if needed
        if !certificateStore.hasCertificate() {
            try CertificateHelper.generateSelfSignedCertificate(store: certificateStore)
        }

        // Perform pairing with callback for PIN
        try await performPairing(pinProvider: pinProvider)
    }

    /// Send play/pause command to Shield TV
    /// - Throws: ShieldClientError if not paired or command fails
    public func playPause() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.mediaPlayPause.rawValue)
    }

    /// Send play command to Shield TV
    public func play() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.mediaPlay.rawValue)
    }

    /// Send pause command to Shield TV
    public func pause() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.mediaPause.rawValue)
    }

    /// Wake up Shield TV (power on if sleeping)
    /// - Throws: ShieldClientError if not paired or command fails
    public func wakeUp() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.wakeUp.rawValue)
    }

    /// Power off Shield TV
    /// - Throws: ShieldClientError if not paired or command fails
    public func powerOff() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.power.rawValue)
    }

    /// Send D-pad up command to Shield TV
    public func dpadUp() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.dpadUp.rawValue)
    }

    /// Send D-pad down command to Shield TV
    public func dpadDown() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.dpadDown.rawValue)
    }

    /// Send D-pad left command to Shield TV
    public func dpadLeft() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.dpadLeft.rawValue)
    }

    /// Send D-pad right command to Shield TV
    public func dpadRight() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.dpadRight.rawValue)
    }

    /// Send D-pad center (select) command to Shield TV
    public func dpadCenter() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.dpadCenter.rawValue)
    }

    /// Send back command to Shield TV
    public func back() async throws {
        guard isPaired else {
            throw ShieldClientError.notPaired
        }
        try await sendKeyCommand(keyCode: KeyCode.back.rawValue)
    }

    // MARK: - Private Implementation

    private func performPairing(pinProvider: () async throws -> String) async throws {
        let connection = AndroidTVConnection()

        do {
            // Connect to pairing port (6467)
            try await connection.connect(host: host, port: 6467, useTLS: true, certificateStore: certificateStore)

            // Send pairing request
            let pairingRequest = AndroidTVMessages.createPairingRequest(
                clientName: "MediaControl",
                serviceName: "Shield TV"
            )
            try await connection.sendMessage(pairingRequest)

            // Wait for pairing ACK
            _ = try await connection.receiveMessage(timeout: 5.0)

            // Send options request
            let optionsRequest = AndroidTVMessages.createOptionsRequest()
            try await connection.sendMessage(optionsRequest)

            // Wait for options response and parse encoding type
            let optionsResponse = try await connection.receiveMessage(timeout: 5.0)
            let encodingType = parseEncodingType(from: optionsResponse)

            // Send configuration request
            let configRequest = AndroidTVMessages.createConfigurationRequest(encodingType: encodingType)
            try await connection.sendMessage(configRequest)

            // Wait for configuration ACK
            _ = try await connection.receiveMessage(timeout: 5.0)

            // PIN should appear on TV NOW - get it from user
            let pin = try await pinProvider()

            // Validate PIN format
            guard pin.count == 6, pin.allSatisfy({ $0.isHexDigit }) else {
                throw ShieldClientError.invalidPIN
            }

            // Create and send secret
            let secret = try createSecret(pin: pin, serverCertificate: connection.serverCertificate)
            let secretMessage = AndroidTVMessages.createSecretMessage(secret: secret)
            try await connection.sendMessage(secretMessage)

            // Wait for and parse secret response
            let secretResponse = try await connection.receiveMessage(timeout: 5.0)
            let status = parseSecretStatus(from: secretResponse)

            guard status == 200 else {
                throw ShieldClientError.connectionFailed("PIN rejected (status \(status))")
            }

            connection.disconnect()

        } catch let error as ShieldClientError {
            connection.disconnect()
            throw error
        } catch {
            connection.disconnect()
            throw ShieldClientError.connectionFailed(error.localizedDescription)
        }
    }

    private func sendKeyCommand(keyCode: UInt32) async throws {
        let connection = AndroidTVConnection()

        do {
            // Connect to remote port (6466)
            try await connection.connect(host: host, port: 6466, useTLS: true, certificateStore: certificateStore)

            // Wait for Shield's configuration message
            _ = try await connection.receiveMessage(timeout: 3.0)

            // Send RemoteConfigure response
            let configResponse = AndroidTVMessages.createRemoteConfigureMessage()
            try await connection.sendMessage(configResponse)

            // Handle RemoteSetActive handshake
            do {
                let setActiveMsg = try await connection.receiveMessage(timeout: 3.0)
                if setActiveMsg.count > 0 && setActiveMsg[0] == 0x12 {
                    let setActiveResponse = AndroidTVMessages.createRemoteSetActiveMessage()
                    try await connection.sendMessage(setActiveResponse)
                }
            } catch {
                // May not always send this message
            }

            // Send key press
            let keyPress = AndroidTVMessages.createKeyPressMessage(keyCode: keyCode)
            try await connection.sendMessage(keyPress)

            // Small delay to ensure delivery
            try await Task.sleep(nanoseconds: 500_000_000)

            connection.disconnect()

        } catch let error as ShieldClientError {
            connection.disconnect()
            throw error
        } catch {
            connection.disconnect()
            throw ShieldClientError.timeout
        }
    }

    private func parseEncodingType(from response: Data) -> UInt8 {
        // Parse encoding type from options response
        // Response format: ...a2 01 XX 12 04 08 YY 10 06...
        // Look for pattern 0x12 0x04 0x08 [type]
        var encodingType: UInt8 = 0 // Default to hexadecimal

        if response.count >= 13 {
            for index in 0..<(response.count - 3) {
                if response[index] == 0x12 && response[index+1] == 0x04 && response[index+2] == 0x08 {
                    encodingType = response[index+3]
                    break
                }
            }
        }

        return encodingType
    }

    private func parseSecretStatus(from response: Data) -> Int {
        // Parse status from secret response
        // Response format: 08 02 10 [status_varint]
        var status = 0

        for index in 0..<response.count {
            if response[index] == 0x10 && index + 1 < response.count {
                let byte1 = response[index + 1]
                if byte1 & 0x80 != 0 && index + 2 < response.count {
                    // Multi-byte varint
                    let byte2 = response[index + 2]
                    status = Int(byte1 & 0x7F) | (Int(byte2) << 7)
                } else {
                    // Single byte
                    status = Int(byte1)
                }
                break
            }
        }

        return status
    }

    private func createSecret(pin: String, serverCertificate: SecCertificate?) throws -> [UInt8] {
        // Convert PIN from hex string to bytes
        guard let pinData = Data(hexString: pin), pinData.count == 3 else {
            throw ShieldClientError.invalidPIN
        }

        let pinBytes = Array(pinData)
        let pinHashBytes = Data([pinBytes[1], pinBytes[2]])

        // Load client certificate
        let identity = try certificateStore.loadIdentity()

        var clientCert: SecCertificate?
        let status = SecIdentityCopyCertificate(identity, &clientCert)
        guard status == errSecSuccess, let cert = clientCert else {
            throw ShieldClientError.connectionFailed("Failed to load client certificate")
        }

        guard let serverCert = serverCertificate else {
            throw ShieldClientError.connectionFailed("No server certificate")
        }

        // Extract RSA components and create SHA256 hash
        let clientComponents = try ShieldRemoteHelpers.extractRSAComponents(from: cert)
        let serverComponents = try ShieldRemoteHelpers.extractRSAComponents(from: serverCert)

        return ShieldRemoteHelpers.createSecretHash(
            clientComponents: clientComponents,
            serverComponents: serverComponents,
            pinHashBytes: pinHashBytes
        )
    }
}

// MARK: - Public Error Type

public enum ShieldClientError: LocalizedError {
    case notPaired
    case connectionFailed(String)
    case invalidPIN
    case timeout

    public var errorDescription: String? {
        switch self {
        case .notPaired:
            return "Shield TV: Not paired. Please pair first."
        case .connectionFailed(let message):
            return "Shield TV: \(message)"
        case .invalidPIN:
            return "Invalid PIN. Must be 6 hex characters."
        case .timeout:
            return "Shield TV: Request timeout. Is device on?"
        }
    }
}
