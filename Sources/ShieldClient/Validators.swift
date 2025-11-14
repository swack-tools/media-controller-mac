import Foundation

/// Validation utilities for IP addresses and PINs
public struct Validators {
    /// Validates IPv4 address format
    /// - Parameter ip: IP address string to validate
    /// - Returns: True if valid IPv4 address
    public static func isValidIPAddress(_ ip: String) -> Bool {
        // Check basic format: xxx.xxx.xxx.xxx
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else {
            return false
        }

        // Validate each octet
        for component in components {
            guard !component.isEmpty,
                  let octet = Int(component),
                  octet >= 0 && octet <= 255 else {
                return false
            }
        }

        return true
    }

    /// Validates PIN format (6-character hexadecimal)
    /// - Parameter pin: PIN string to validate
    /// - Returns: True if valid 6-character hex PIN
    public static func isValidPIN(_ pin: String) -> Bool {
        // Must be exactly 6 characters
        guard pin.count == 6 else {
            return false
        }

        // Must contain only hexadecimal characters (0-9, A-F, a-f)
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let pinCharacterSet = CharacterSet(charactersIn: pin)

        return hexCharacterSet.isSuperset(of: pinCharacterSet)
    }
}
