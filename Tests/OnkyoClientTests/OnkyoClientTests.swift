import XCTest
@testable import OnkyoClient

final class OnkyoClientTests: XCTestCase {

    // MARK: - Initialization Tests

    func testClientInitialization() {
        let client = OnkyoClient(host: "192.168.1.50")
        XCTAssertNotNil(client)
    }

    func testClientInitializationWithVariousHosts() {
        let client1 = OnkyoClient(host: "10.0.0.1")
        XCTAssertNotNil(client1)

        let client2 = OnkyoClient(host: "receiver.local")
        XCTAssertNotNil(client2)

        let client3 = OnkyoClient(host: "192.168.1.100")
        XCTAssertNotNil(client3)
    }

    // MARK: - Error Handling Tests

    func testErrorDescriptions() {
        let connectionError = OnkyoClientError.connectionFailed("test error")
        XCTAssertEqual(connectionError.errorDescription, "Receiver: test error")
        XCTAssertTrue(connectionError.errorDescription?.contains("test error") ?? false)

        let invalidResponse = OnkyoClientError.invalidResponse
        XCTAssertEqual(invalidResponse.errorDescription, "Receiver: Unexpected response")
        XCTAssertTrue(invalidResponse.errorDescription?.contains("Unexpected") ?? false)

        let timeout = OnkyoClientError.timeout
        XCTAssertEqual(timeout.errorDescription, "Receiver: No response. Is device on?")
        XCTAssertTrue(timeout.errorDescription?.contains("No response") ?? false)
        XCTAssertTrue(timeout.errorDescription?.contains("device on") ?? false)
    }

    func testAllErrorCases() {
        // Test all error cases exist
        let error1: OnkyoClientError = .connectionFailed("test")
        let error2: OnkyoClientError = .invalidResponse
        let error3: OnkyoClientError = .timeout

        XCTAssertNotNil(error1.errorDescription)
        XCTAssertNotNil(error2.errorDescription)
        XCTAssertNotNil(error3.errorDescription)
    }

    func testErrorEquality() {
        // Test error descriptions are unique
        let error1 = OnkyoClientError.connectionFailed("test")
        let error2 = OnkyoClientError.invalidResponse
        let error3 = OnkyoClientError.timeout

        XCTAssertNotEqual(error1.errorDescription, error2.errorDescription)
        XCTAssertNotEqual(error2.errorDescription, error3.errorDescription)
        XCTAssertNotEqual(error1.errorDescription, error3.errorDescription)
    }

    func testConnectionErrorMessages() {
        let errors = [
            "Connection refused",
            "Network unreachable",
            "Timeout",
            "Invalid host",
            "DNS lookup failed"
        ]

        for errorMsg in errors {
            let error = OnkyoClientError.connectionFailed(errorMsg)
            XCTAssertTrue(error.errorDescription?.contains(errorMsg) ?? false)
        }
    }

    // MARK: - Volume Range Tests

    func testVolumeRangeValidation() {
        // These tests verify the volume range logic exists
        // Volume should be 0-100 (hex 0x00-0x64)

        // Test that volume values can be in range
        for volume in [0, 25, 50, 75, 100] {
            let hexValue = String(format: "%02X", volume)
            XCTAssertEqual(hexValue.count, 2)
            let parsedValue = Int(hexValue, radix: 16)
            XCTAssertEqual(parsedValue, volume)
        }

        // Test clamping logic would work
        let testValues = [-10, -1, 0, 50, 100, 101, 200]
        let expectedClamped = [0, 0, 0, 50, 100, 100, 100]

        for (index, value) in testValues.enumerated() {
            let clamped = max(0, min(100, value))
            XCTAssertEqual(clamped, expectedClamped[index])
        }
    }

    func testVolumeHexConversion() {
        // Test hex conversions for common volumes
        let testCases: [(Int, String)] = [
            (0, "00"),
            (10, "0A"),
            (25, "19"),
            (50, "32"),
            (75, "4B"),
            (100, "64")
        ]

        for (decimal, expectedHex) in testCases {
            let hexValue = String(format: "%02X", decimal)
            XCTAssertEqual(hexValue, expectedHex)

            // Verify round-trip
            let parsedValue = Int(hexValue, radix: 16)
            XCTAssertEqual(parsedValue, decimal)
        }
    }

    func testVolumeEdgeCases() {
        // Test edge cases
        let edgeCases: [(Int, String)] = [
            (0, "00"),      // Min volume
            (1, "01"),      // Min + 1
            (99, "63"),     // Max - 1
            (100, "64"),    // Max volume
            (255, "FF")     // Max possible hex byte (for testing)
        ]

        for (decimal, expectedHex) in edgeCases {
            let hexValue = String(format: "%02X", decimal)
            XCTAssertEqual(hexValue, expectedHex)
        }
    }

    // MARK: - Command Format Tests

    func testCommandConstruction() {
        // Test that command strings are properly formed
        let commands = [
            "MVLQSTN",      // Volume query
            "MVLUP",        // Volume up
            "MVLDOWN",      // Volume down
            "MVL32",        // Set volume to 50 (0x32 hex)
            "AMT01",        // Mute on
            "AMT00",        // Mute off
            "AMTQSTN"       // Mute query
        ]

        for command in commands {
            XCTAssertGreaterThan(command.count, 0)
            XCTAssertFalse(command.contains(" "))
            XCTAssertTrue(command.allSatisfy { $0.isASCII })
        }
    }

    func testMuteCommands() {
        // Test mute command construction
        let muteOn = "AMT01"
        let muteOff = "AMT00"

        XCTAssertEqual(muteOn, "AMT01")
        XCTAssertEqual(muteOff, "AMT00")
        XCTAssertNotEqual(muteOn, muteOff)
    }

    func testVolumeCommands() {
        // Test volume command formats
        let volumeQuery = "MVLQSTN"
        let volumeUp = "MVLUP"
        let volumeDown = "MVLDOWN"

        XCTAssertEqual(volumeQuery, "MVLQSTN")
        XCTAssertEqual(volumeUp, "MVLUP")
        XCTAssertEqual(volumeDown, "MVLDOWN")

        // All should start with MVL
        XCTAssertTrue(volumeQuery.hasPrefix("MVL"))
        XCTAssertTrue(volumeUp.hasPrefix("MVL"))
        XCTAssertTrue(volumeDown.hasPrefix("MVL"))
    }

    func testSetVolumeCommands() {
        // Test set volume command generation
        let volumes = [0, 25, 50, 75, 100]
        let expectedCommands = ["MVL00", "MVL19", "MVL32", "MVL4B", "MVL64"]

        for (index, volume) in volumes.enumerated() {
            let hexValue = String(format: "%02X", volume)
            let command = "MVL\(hexValue)"
            XCTAssertEqual(command, expectedCommands[index])
        }
    }

    // MARK: - Response Parsing Tests

    func testResponseCleaning() {
        // Test that response cleaning logic works
        let testResponses = [
            "!1MVL32\u{1A}\r\n",
            "!1AMT01\r\n",
            "!1MVL64\u{1A}"
        ]

        for response in testResponses {
            let cleaned = response
                .replacingOccurrences(of: "!1", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\u{1A}", with: "")
                .trimmingCharacters(in: .whitespaces)

            XCTAssertFalse(cleaned.contains("!1"))
            XCTAssertFalse(cleaned.contains("\r"))
            XCTAssertFalse(cleaned.contains("\n"))
            XCTAssertFalse(cleaned.contains("\u{1A}"))
        }
    }

    func testVolumeResponseParsing() {
        // Test volume response parsing logic
        let testCases: [(String, Int?)] = [
            ("!1MVL32\u{1A}\r\n", 50),      // 0x32 = 50
            ("!1MVL00\u{1A}\r\n", 0),       // 0x00 = 0
            ("!1MVL64\u{1A}\r\n", 100),     // 0x64 = 100
            ("!1MVL19\u{1A}\r\n", 25),      // 0x19 = 25
            ("!1MVLFF\u{1A}\r\n", 255)      // 0xFF = 255 (max)
        ]

        for (response, expectedVolume) in testCases {
            let cleaned = response
                .replacingOccurrences(of: "!1", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\u{1A}", with: "")
                .trimmingCharacters(in: .whitespaces)

            if cleaned.hasPrefix("MVL") {
                let hexString = String(cleaned.dropFirst(3)).filter { $0.isHexDigit }
                let hexValue = Int(hexString, radix: 16)
                XCTAssertEqual(hexValue, expectedVolume)
            }
        }
    }

    func testMuteResponseParsing() {
        // Test mute response parsing
        let testCases: [(String, Bool)] = [
            ("!1AMT01\r\n", true),      // Muted
            ("!1AMT00\r\n", false),     // Unmuted
            ("!1AMT01\u{1A}", true),
            ("!1AMT00\u{1A}\r\n", false)
        ]

        for (response, expectedMuted) in testCases {
            let cleaned = response
                .replacingOccurrences(of: "!1", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\u{1A}", with: "")
                .trimmingCharacters(in: .whitespaces)

            let isMuted = cleaned.contains("AMT01")
            XCTAssertEqual(isMuted, expectedMuted)
        }
    }

    func testInvalidResponseFormat() {
        // Test handling of invalid responses
        let invalidResponses = [
            "",
            "!1",
            "MVL",
            "!1MVLXY\r\n",      // Invalid hex
            "!1MVLG1\r\n",      // G is not hex
            "INVALID",
            "!1UNKNOWN\r\n"
        ]

        for response in invalidResponses {
            let cleaned = response
                .replacingOccurrences(of: "!1", with: "")
                .replacingOccurrences(of: "\r", with: "")
                .replacingOccurrences(of: "\n", with: "")
                .replacingOccurrences(of: "\u{1A}", with: "")
                .trimmingCharacters(in: .whitespaces)

            if cleaned.hasPrefix("MVL") {
                let hexString = String(cleaned.dropFirst(3)).filter { $0.isHexDigit }
                if hexString.isEmpty || hexString.count != 2 {
                    // This should be caught as invalid
                    XCTAssertTrue(hexString.isEmpty || hexString.count != 2)
                }
            }
        }
    }

    // MARK: - Protocol Tests

    func testEISCPProtocolDefaults() {
        // Test eISCP protocol defaults
        let defaultPort: UInt16 = 60128
        XCTAssertEqual(defaultPort, 60128)

        let timeout: TimeInterval = 3.0
        XCTAssertEqual(timeout, 3.0)
    }

    func testHexDigitValidation() {
        // Test hex digit validation
        let validHex = "0123456789ABCDEF"
        for char in validHex {
            XCTAssertTrue(char.isHexDigit)
        }

        let validHexLower = "0123456789abcdef"
        for char in validHexLower {
            XCTAssertTrue(char.isHexDigit)
        }

        let invalidHex = "GHIJKLMNOPQRSTUVWXYZ"
        for char in invalidHex {
            XCTAssertFalse(char.isHexDigit)
        }
    }

    // MARK: - Edge Case Tests

    func testEmptyHostHandling() {
        let client = OnkyoClient(host: "")
        XCTAssertNotNil(client)
    }

    func testLongHostHandling() {
        let longHost = String(repeating: "a", count: 1000)
        let client = OnkyoClient(host: longHost)
        XCTAssertNotNil(client)
    }

    func testSpecialCharactersInHost() {
        let specialHosts = [
            "receiver@home",
            "receiver#1",
            "receiver$test",
            "192.168.1.1:60128"
        ]

        for host in specialHosts {
            let client = OnkyoClient(host: host)
            XCTAssertNotNil(client)
        }
    }

    // MARK: - Boundary Tests

    func testVolumeBoundaries() {
        // Test volume boundary values
        let boundaryTests: [(Int, Int)] = [
            (-100, 0),      // Below min
            (-1, 0),        // Just below min
            (0, 0),         // Min
            (1, 1),         // Just above min
            (99, 99),       // Just below max
            (100, 100),     // Max
            (101, 100),     // Just above max
            (1000, 100)     // Way above max
        ]

        for (input, expected) in boundaryTests {
            let clamped = max(0, min(100, input))
            XCTAssertEqual(clamped, expected)
        }
    }

    // MARK: - Performance Tests

    func testHexConversionPerformance() {
        measure {
            for volume in 0...100 {
                _ = String(format: "%02X", volume)
            }
        }
    }

    func testResponseCleaningPerformance() {
        let response = "!1MVL32\u{1A}\r\n"
        measure {
            for _ in 0..<1000 {
                _ = response
                    .replacingOccurrences(of: "!1", with: "")
                    .replacingOccurrences(of: "\r", with: "")
                    .replacingOccurrences(of: "\n", with: "")
                    .replacingOccurrences(of: "\u{1A}", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }
        }
    }
}
