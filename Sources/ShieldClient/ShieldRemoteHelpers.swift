import Foundation
import CryptoKit
import Security

/// Internal helpers for Shield TV remote protocol
enum ShieldRemoteHelpers {

    /// Extract RSA public key modulus and exponent from certificate
    static func extractRSAComponents(from certificate: SecCertificate) throws -> (modulus: Data, exponent: Data) {
        // Get public key from certificate
        guard let publicKey = SecCertificateCopyKey(certificate) else {
            throw ShieldClientError.connectionFailed("Failed to extract public key")
        }

        // Export public key data
        var error: Unmanaged<CFError>?
        guard let keyData = SecKeyCopyExternalRepresentation(publicKey, &error) as Data? else {
            let err = error?.takeRetainedValue()
            let errorMsg = err?.localizedDescription ?? "unknown"
            throw ShieldClientError.connectionFailed("Failed to export public key: \(errorMsg)")
        }

        // Parse RSA public key structure
        // Public key format: Header (8 bytes) + Modulus (~256 bytes) + Exponent (3 bytes)
        let modulusStart = 8
        let modulusEnd = keyData.count - 5
        guard modulusEnd > modulusStart else {
            throw ShieldClientError.connectionFailed("Public key data too small")
        }

        var modulus = keyData.subdata(in: modulusStart..<modulusEnd)

        // Remove leading null byte if present
        if modulus.count >= 257 && modulus[0] == 0x00 {
            modulus = modulus.subdata(in: 1..<modulus.count)
        }

        // Extract exponent: last 3 bytes
        let exponent = keyData.subdata(in: (keyData.count - 3)..<keyData.count)

        return (modulus, exponent)
    }

    /// Create secret hash from RSA components and PIN
    /// secret = SHA256(client_mod + client_exp + server_mod + server_exp + PIN[1:3])
    static func createSecretHash(
        clientComponents: (modulus: Data, exponent: Data),
        serverComponents: (modulus: Data, exponent: Data),
        pinHashBytes: Data
    ) -> [UInt8] {
        var shaHash = SHA256()
        shaHash.update(data: clientComponents.modulus)
        shaHash.update(data: clientComponents.exponent)
        shaHash.update(data: serverComponents.modulus)
        shaHash.update(data: serverComponents.exponent)
        shaHash.update(data: pinHashBytes)

        return Array(shaHash.finalize())
    }
}

// MARK: - Data Extensions

extension Data {
    /// Create Data from a hex string
    init?(hexString: String) {
        // Validate string contains only valid hex characters
        let validHexCharacters = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        guard hexString.unicodeScalars.allSatisfy({ validHexCharacters.contains($0) }) else {
            return nil
        }

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
