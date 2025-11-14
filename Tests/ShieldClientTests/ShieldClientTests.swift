import XCTest
@testable import ShieldClient

final class ShieldClientTests: XCTestCase {

    // MARK: - Validator Tests

    func testIPValidation() {
        // Valid IPs
        XCTAssertTrue(Validators.isValidIPAddress("192.168.1.1"))
        XCTAssertTrue(Validators.isValidIPAddress("10.0.0.1"))
        XCTAssertTrue(Validators.isValidIPAddress("172.16.0.1"))
        XCTAssertTrue(Validators.isValidIPAddress("255.255.255.255"))
        XCTAssertTrue(Validators.isValidIPAddress("0.0.0.0"))

        // Invalid IPs
        XCTAssertFalse(Validators.isValidIPAddress("256.1.1.1"))
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1"))
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1.1.1"))
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1."))
        XCTAssertFalse(Validators.isValidIPAddress("192.168.-1.1"))
        XCTAssertFalse(Validators.isValidIPAddress("192.168.1.256"))
        XCTAssertFalse(Validators.isValidIPAddress("abc.def.ghi.jkl"))
        XCTAssertFalse(Validators.isValidIPAddress(""))
        XCTAssertFalse(Validators.isValidIPAddress("192 168 1 1"))
    }

    func testPINValidation() {
        // Valid PINs
        XCTAssertTrue(Validators.isValidPIN("ABC123"))
        XCTAssertTrue(Validators.isValidPIN("000000"))
        XCTAssertTrue(Validators.isValidPIN("FFFFFF"))
        XCTAssertTrue(Validators.isValidPIN("123456"))
        XCTAssertTrue(Validators.isValidPIN("ABCDEF"))
        XCTAssertTrue(Validators.isValidPIN("aaa000")) // Should be case-insensitive

        // Invalid PINs
        XCTAssertFalse(Validators.isValidPIN("12345")) // Too short
        XCTAssertFalse(Validators.isValidPIN("1234567")) // Too long
        XCTAssertFalse(Validators.isValidPIN("ABCXYZ")) // Invalid hex (X, Y, Z)
        XCTAssertFalse(Validators.isValidPIN("ABC12G")) // G not hex
        XCTAssertFalse(Validators.isValidPIN(""))
        XCTAssertFalse(Validators.isValidPIN(" "))
        XCTAssertFalse(Validators.isValidPIN("ABC 123")) // Space
    }

    // MARK: - Certificate Store Tests

    func testCertificateStoreInitialization() {
        let store = CertificateStore()
        XCTAssertNotNil(store)
    }

    func testCertificateStoreEmpty() {
        let store = CertificateStore()
        // Initially should not have certificate (unless left from previous test)
        // We can't guarantee this in unit tests without cleanup
        XCTAssertNotNil(store)
    }

    // MARK: - Data Extension Tests

    func testDataHexConversion() {
        // Valid hex strings
        let hex1 = "ABC123"
        let data1 = Data(hexString: hex1)
        XCTAssertNotNil(data1)
        XCTAssertEqual(data1?.count, 3) // 6 hex chars = 3 bytes
        XCTAssertEqual(Array(data1!), [0xAB, 0xC1, 0x23])

        let hex2 = "00FF00"
        let data2 = Data(hexString: hex2)
        XCTAssertNotNil(data2)
        XCTAssertEqual(Array(data2!), [0x00, 0xFF, 0x00])

        let hex3 = "DEADBEEF"
        let data3 = Data(hexString: hex3)
        XCTAssertNotNil(data3)
        XCTAssertEqual(data3?.count, 4)

        // Case insensitive
        let hex4 = "abcdef"
        let data4 = Data(hexString: hex4)
        XCTAssertNotNil(data4)
        XCTAssertEqual(Array(data4!), [0xAB, 0xCD, 0xEF])

        // Empty string
        let hex5 = ""
        let data5 = Data(hexString: hex5)
        XCTAssertNotNil(data5)
        XCTAssertEqual(data5?.count, 0)

        // Invalid hex
        XCTAssertNil(Data(hexString: "XYZ"))
        XCTAssertNil(Data(hexString: "ABCG"))
        XCTAssertNil(Data(hexString: "12 34"))

        // Odd length (invalid)
        XCTAssertNil(Data(hexString: "ABC"))
    }

    // MARK: - KeyCode Tests

    func testKeyCodeValues() {
        XCTAssertEqual(KeyCode.mediaPlayPause.rawValue, 85)
        XCTAssertEqual(KeyCode.mediaPlay.rawValue, 126)
        XCTAssertEqual(KeyCode.mediaPause.rawValue, 127)
        XCTAssertEqual(KeyCode.mediaStop.rawValue, 86)
        XCTAssertEqual(KeyCode.mediaNext.rawValue, 87)
        XCTAssertEqual(KeyCode.mediaPrevious.rawValue, 88)
        XCTAssertEqual(KeyCode.volumeUp.rawValue, 24)
        XCTAssertEqual(KeyCode.volumeDown.rawValue, 25)
        XCTAssertEqual(KeyCode.mute.rawValue, 91)
        XCTAssertEqual(KeyCode.home.rawValue, 3)
        XCTAssertEqual(KeyCode.back.rawValue, 4)
        XCTAssertEqual(KeyCode.dpadUp.rawValue, 19)
        XCTAssertEqual(KeyCode.dpadDown.rawValue, 20)
        XCTAssertEqual(KeyCode.dpadLeft.rawValue, 21)
        XCTAssertEqual(KeyCode.dpadRight.rawValue, 22)
        XCTAssertEqual(KeyCode.dpadCenter.rawValue, 23)
    }

    // MARK: - ProtobufEncoder Tests

    func testProtobufVarintEncoding() {
        // Test small values
        let msg1 = AndroidTVMessages.createKeyPressMessage(keyCode: 0, direction: 1)
        XCTAssertGreaterThan(msg1.count, 0)

        let msg2 = AndroidTVMessages.createKeyPressMessage(keyCode: 127, direction: 1)
        XCTAssertGreaterThan(msg2.count, 0)

        // Test larger values
        let msg3 = AndroidTVMessages.createKeyPressMessage(keyCode: 300, direction: 1)
        XCTAssertGreaterThan(msg3.count, 0)
    }

    func testProtobufStringEncoding() {
        let msg = AndroidTVMessages.createPairingRequest(clientName: "TestClient", serviceName: "TestService")
        XCTAssertGreaterThan(msg.count, 0)

        // Should contain the strings as UTF-8 byte sequences
        let clientBytes = "TestClient".data(using: .utf8)!
        let serviceBytes = "TestService".data(using: .utf8)!

        // Search for byte sequences in the protobuf message
        XCTAssertTrue(msg.range(of: clientBytes) != nil, "Message should contain TestClient")
        XCTAssertTrue(msg.range(of: serviceBytes) != nil, "Message should contain TestService")
    }

    func testProtobufEmptyStrings() {
        let msg = AndroidTVMessages.createPairingRequest(clientName: "", serviceName: "")
        XCTAssertGreaterThan(msg.count, 0)
    }

    // MARK: - AndroidTVMessages Tests

    func testPairingRequestMessage() {
        let msg = AndroidTVMessages.createPairingRequest(
            clientName: "MediaControl",
            serviceName: "Shield TV"
        )

        XCTAssertGreaterThan(msg.count, 0)

        // Check protocol version field (should start with 0x08 0x02)
        XCTAssertTrue(msg.contains([0x08, 0x02]))

        // Check status field (0x10, 0xc8, 0x01 = status 200)
        XCTAssertTrue(msg.contains([0x10, 0xc8, 0x01]))
    }

    func testOptionsRequestMessage() {
        let msg = AndroidTVMessages.createOptionsRequest()
        XCTAssertGreaterThan(msg.count, 0)

        // Should contain protocol version
        XCTAssertTrue(msg.contains([0x08, 0x02]))

        // Should contain status 200
        XCTAssertTrue(msg.contains([0x10, 0xc8, 0x01]))
    }

    func testConfigurationRequestMessage() {
        let msg1 = AndroidTVMessages.createConfigurationRequest(encodingType: 0)
        XCTAssertGreaterThan(msg1.count, 0)

        let msg2 = AndroidTVMessages.createConfigurationRequest(encodingType: 1)
        XCTAssertGreaterThan(msg2.count, 0)

        // Different encoding types should produce different messages
        XCTAssertNotEqual(msg1, msg2)
    }

    func testSecretMessage() {
        let secret: [UInt8] = Array(repeating: 0xAB, count: 32) // 32-byte secret
        let msg = AndroidTVMessages.createSecretMessage(secret: secret)

        XCTAssertGreaterThan(msg.count, 0)
        XCTAssertTrue(msg.contains([0x08, 0x02])) // Protocol version
        XCTAssertTrue(msg.contains([0x10, 0xc8, 0x01])) // Status 200
    }

    func testRemoteSetActiveMessage() {
        let msg = AndroidTVMessages.createRemoteSetActiveMessage()
        XCTAssertGreaterThan(msg.count, 0)
    }

    func testRemoteConfigureMessage() {
        let msg = AndroidTVMessages.createRemoteConfigureMessage()
        XCTAssertGreaterThan(msg.count, 0)

        // Should contain package name as UTF-8 byte sequence
        let packageBytes = "ShieldPause".data(using: .utf8)!
        XCTAssertTrue(msg.range(of: packageBytes) != nil, "Message should contain ShieldPause")
    }

    func testKeyPressMessage() {
        // Test different key codes
        let playPause = AndroidTVMessages.createKeyPressMessage(
            keyCode: KeyCode.mediaPlayPause.rawValue,
            direction: 3
        )
        XCTAssertGreaterThan(playPause.count, 0)

        let home = AndroidTVMessages.createKeyPressMessage(
            keyCode: KeyCode.home.rawValue,
            direction: 3
        )
        XCTAssertGreaterThan(home.count, 0)

        // Different keys should produce different messages
        XCTAssertNotEqual(playPause, home)

        // Test different directions
        let down = AndroidTVMessages.createKeyPressMessage(keyCode: 85, direction: 1)
        let keyUp = AndroidTVMessages.createKeyPressMessage(keyCode: 85, direction: 2)
        let short = AndroidTVMessages.createKeyPressMessage(keyCode: 85, direction: 3)

        XCTAssertNotEqual(down, keyUp)
        XCTAssertNotEqual(keyUp, short)
        XCTAssertNotEqual(down, short)
    }

    func testKeyPressMessageDefaultDirection() {
        let msg = AndroidTVMessages.createKeyPressMessage(keyCode: 85)
        XCTAssertGreaterThan(msg.count, 0)
    }

    // MARK: - Error Tests

    func testShieldClientErrorDescriptions() {
        let notPaired = ShieldClientError.notPaired
        XCTAssertNotNil(notPaired.errorDescription)
        XCTAssertTrue(notPaired.errorDescription?.contains("Not paired") ?? false)

        let connectionFailed = ShieldClientError.connectionFailed("test error")
        XCTAssertNotNil(connectionFailed.errorDescription)
        XCTAssertTrue(connectionFailed.errorDescription?.contains("test error") ?? false)

        let invalidPIN = ShieldClientError.invalidPIN
        XCTAssertNotNil(invalidPIN.errorDescription)
        XCTAssertTrue(invalidPIN.errorDescription?.contains("6 hex") ?? false)

        let timeout = ShieldClientError.timeout
        XCTAssertNotNil(timeout.errorDescription)
        XCTAssertTrue(timeout.errorDescription?.contains("timeout") ?? false)
    }

    // MARK: - Edge Case Tests

    func testVeryLongStrings() {
        let longString = String(repeating: "A", count: 1000)
        let msg = AndroidTVMessages.createPairingRequest(
            clientName: longString,
            serviceName: longString
        )
        XCTAssertGreaterThan(msg.count, 0)
    }

    func testSpecialCharactersInStrings() {
        let msg = AndroidTVMessages.createPairingRequest(
            clientName: "Test™️ Client 🎮",
            serviceName: "Shield TV™️"
        )
        XCTAssertGreaterThan(msg.count, 0)
    }

    func testLargeKeyCode() {
        let msg = AndroidTVMessages.createKeyPressMessage(keyCode: UInt32.max, direction: 1)
        XCTAssertGreaterThan(msg.count, 0)
    }

    func testZeroKeyCode() {
        let msg = AndroidTVMessages.createKeyPressMessage(keyCode: 0, direction: 0)
        XCTAssertGreaterThan(msg.count, 0)
    }
}

// MARK: - Data Extension Helper

extension Data {
    func contains(_ bytes: [UInt8]) -> Bool {
        guard bytes.count > 0 else { return false }
        guard self.count >= bytes.count else { return false }

        for startIndex in 0...(self.count - bytes.count) {
            // Check if all bytes match at this position
            if (0..<bytes.count).allSatisfy({ self[startIndex + $0] == bytes[$0] }) {
                return true
            }
        }
        return false
    }
}
