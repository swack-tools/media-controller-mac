import Foundation

enum ValidationError: LocalizedError {
    case invalidIPAddress(String)
    case invalidPIN(String)

    var errorDescription: String? {
        switch self {
        case .invalidIPAddress(let message):
            return "Invalid IP address: \(message)"
        case .invalidPIN(let message):
            return "Invalid PIN: \(message)"
        }
    }
}

struct Validators {
    /// Validates IPv4 address format
    /// - Parameter ip: IP address string to validate
    /// - Returns: True if valid IPv4 address
    static func isValidIPAddress(_ ip: String) -> Bool {
        // Check basic format: xxx.xxx.xxx.xxx
        // Use components(separatedBy:) instead of split() to catch leading/trailing dots
        let components = ip.components(separatedBy: ".")
        guard components.count == 4 else {
            return false
        }

        // Validate each octet
        for component in components {
            // Check for empty components (from leading/trailing dots)
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
    static func isValidPIN(_ pin: String) -> Bool {
        // Must be exactly 6 characters
        guard pin.count == 6 else {
            return false
        }

        // Must contain only hexadecimal characters (0-9, A-F, a-f)
        let hexCharacterSet = CharacterSet(charactersIn: "0123456789ABCDEFabcdef")
        let pinCharacterSet = CharacterSet(charactersIn: pin)

        return hexCharacterSet.isSuperset(of: pinCharacterSet)
    }

    /// Prompts user for IP address with validation
    /// - Returns: Valid IP address string
    static func promptForIPAddress() -> String {
        while true {
            print("Enter Shield TV IP address: ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  !input.isEmpty else {
                print("IP address cannot be empty")
                continue
            }

            if isValidIPAddress(input) {
                return input
            } else {
                print("Invalid IP address format. Please use format: xxx.xxx.xxx.xxx")
            }
        }
    }

    /// Prompts user for pairing PIN with validation
    /// - Returns: Valid 6-character hex PIN
    static func promptForPIN() -> String {
        while true {
            print("Enter 6-character pairing PIN from TV: ", terminator: "")
            guard let input = readLine()?.trimmingCharacters(in: .whitespaces),
                  !input.isEmpty else {
                print("PIN cannot be empty")
                continue
            }

            if isValidPIN(input) {
                return input.uppercased()
            } else {
                print("Invalid PIN format. Must be exactly 6 hexadecimal characters (0-9, A-F)")
            }
        }
    }
}
