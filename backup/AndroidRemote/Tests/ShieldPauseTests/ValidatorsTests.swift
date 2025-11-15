import XCTest
@testable import ShieldPauseCore

final class ValidatorsTests: XCTestCase {

    // MARK: - IP Address Validation Tests

    func testValidIPv4Addresses() {
        // Test valid IP addresses
        XCTAssertTrue(Validators.isValidIPAddress("192.168.1.1"))
        XCTAssertTrue(Validators.isValidIPAddress("10.0.0.1"))
        XCTAssertTrue(Validators.isValidIPAddress("172.16.0.1"))
        XCTAssertTrue(Validators.isValidIPAddress("255.255.255.255"))
        XCTAssertTrue(Validators.isValidIPAddress("0.0.0.0"))
        XCTAssertTrue(Validators.isValidIPAddress("127.0.0.1"))
    }

    func testInvalidIPv4Addresses() {
        // Test invalid IP addresses - wrong format
        XCTAssertFalse(Validators.isValidIPAddress("256.1.1.1"))  // Octet > 255
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1"))   // Missing octet
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1.1.1")) // Too many octets
        XCTAssertFalse(Validators.isValidIPAddress("192.168.-1.1")) // Negative number
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1.256")) // Octet > 255
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1.1a")) // Letter in octet
        XCTAssertFalse(Validators.isValidIPAddress("abc.def.ghi.jkl")) // All letters
        XCTAssertFalse(Validators.isValidIPAddress(""))  // Empty string
        XCTAssertFalse(Validators.isValidIPAddress("...")) // Just dots
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1.")) // Trailing dot
        XCTAssertFalse(Validators.isValidIPAddress(".192.168.1.1")) // Leading dot
    }

    func testIPv4EdgeCases() {
        // Test edge cases
        XCTAssertTrue(Validators.isValidIPAddress("0.0.0.0"))     // All zeros
        XCTAssertTrue(Validators.isValidIPAddress("255.255.255.255")) // All max
        XCTAssertFalse(Validators.isValidIPAddress("192 168 1 1")) // Spaces instead of dots
        XCTAssertFalse(Validators.isValidIPAddress("192,168,1,1")) // Commas instead of dots
    }

    // MARK: - PIN Validation Tests

    func testValidPINs() {
        // Test valid 6-character hexadecimal PINs
        XCTAssertTrue(Validators.isValidPIN("4D292B"))
        XCTAssertTrue(Validators.isValidPIN("ABCDEF"))
        XCTAssertTrue(Validators.isValidPIN("123456"))
        XCTAssertTrue(Validators.isValidPIN("000000"))
        XCTAssertTrue(Validators.isValidPIN("FFFFFF"))
        XCTAssertTrue(Validators.isValidPIN("abcdef")) // Lowercase should be valid
        XCTAssertTrue(Validators.isValidPIN("ABC123"))
        XCTAssertTrue(Validators.isValidPIN("9A8B7C"))
    }

    func testInvalidPINs() {
        // Test invalid PINs - wrong length
        XCTAssertFalse(Validators.isValidPIN("12345"))   // Too short
        XCTAssertFalse(Validators.isValidPIN("1234567")) // Too long
        XCTAssertFalse(Validators.isValidPIN(""))        // Empty

        // Test invalid PINs - wrong characters
        XCTAssertFalse(Validators.isValidPIN("GHIJKL")) // Non-hex letters
        XCTAssertFalse(Validators.isValidPIN("12345G")) // Contains non-hex
        XCTAssertFalse(Validators.isValidPIN("12345!")) // Contains special char
        XCTAssertFalse(Validators.isValidPIN("ABC XYZ")) // Contains space
        XCTAssertFalse(Validators.isValidPIN("12-34-56")) // Contains dash
    }

    func testPINEdgeCases() {
        // Test edge cases
        XCTAssertTrue(Validators.isValidPIN("0F1A2B"))  // Mixed case
        XCTAssertTrue(Validators.isValidPIN("f0f0f0"))  // All lowercase
        XCTAssertFalse(Validators.isValidPIN("      ")) // All spaces
        XCTAssertFalse(Validators.isValidPIN("123\n45")) // Contains newline
        XCTAssertFalse(Validators.isValidPIN("123\t45")) // Contains tab
    }

    // MARK: - Performance Tests

    func testIPValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Validators.isValidIPAddress("192.168.1.1")
            }
        }
    }

    func testPINValidationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = Validators.isValidPIN("4D292B")
            }
        }
    }
}
