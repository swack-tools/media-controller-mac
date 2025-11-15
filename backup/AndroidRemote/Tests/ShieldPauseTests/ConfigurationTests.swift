import XCTest
import Foundation
@testable import ShieldPauseCore

final class ConfigurationTests: XCTestCase {

    var tempDirectory: URL!

    override func setUp() {
        super.setUp()
        // Create a temporary directory for test files
        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try? FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() {
        // Clean up temporary directory
        try? FileManager.default.removeItem(at: tempDirectory)
        super.tearDown()
    }

    // MARK: - Configuration Loading Tests

    func testLoadConfigurationWithNoFile() {
        // Test loading when no .env file exists
        let config = Configuration.load()
        XCTAssertNil(config.shieldHost, "Host should be nil when no config file exists")
    }

    func testLoadConfigurationWithValidFile() throws {
        // Create a temporary .env file
        let envContent = "SHIELD_HOST=192.168.1.100\n"
        let envURL = tempDirectory.appendingPathComponent(".env")
        try envContent.write(to: envURL, atomically: true, encoding: .utf8)

        // Override the env file URL temporarily (would need to modify Configuration for this)
        // For now, we'll test the parsing logic indirectly
    }

    func testConfigurationFileNames() {
        // Test that file names are correctly defined
        XCTAssertEqual(Configuration.envFileName, ".env")
        XCTAssertEqual(Configuration.certFileName, ".shield_cert.pem")
        XCTAssertEqual(Configuration.keyFileName, ".shield_key.pem")
    }

    // MARK: - Configuration Saving Tests

    func testSaveConfiguration() throws {
        // Create a test configuration
        var config = Configuration()
        config.shieldHost = "192.168.1.238"

        // Save it (this will save to current directory, so be careful)
        // In a real test, we'd want to inject the save location
        // For now, we'll just test that it doesn't throw
        XCTAssertNoThrow(try config.save())

        // Clean up the created file
        let envURL = Configuration.envFileURL
        try? FileManager.default.removeItem(at: envURL)
    }

    func testSaveAndLoadRoundTrip() throws {
        // Save a configuration
        var saveConfig = Configuration()
        saveConfig.shieldHost = "10.0.0.1"
        try saveConfig.save()

        // Load it back
        let loadConfig = Configuration.load()
        XCTAssertEqual(loadConfig.shieldHost, "10.0.0.1", "Loaded config should match saved config")

        // Clean up
        try? FileManager.default.removeItem(at: Configuration.envFileURL)
    }

    // MARK: - Certificate Management Tests

    func testHasCertificatesWhenNoneExist() {
        // Clean up any existing certificates
        Configuration.deleteCertificates()

        // Check that hasCertificates returns false
        XCTAssertFalse(Configuration.hasCertificates(), "Should return false when no certificates exist")
    }

    func testDeleteCertificates() {
        // Create dummy certificate files
        let certURL = Configuration.certFileURL
        let keyURL = Configuration.keyFileURL

        try? "dummy cert".write(to: certURL, atomically: true, encoding: .utf8)
        try? "dummy key".write(to: keyURL, atomically: true, encoding: .utf8)

        // Verify they exist
        XCTAssertTrue(FileManager.default.fileExists(atPath: certURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: keyURL.path))

        // Delete them
        Configuration.deleteCertificates()

        // Verify they're gone
        XCTAssertFalse(FileManager.default.fileExists(atPath: certURL.path))
        XCTAssertFalse(FileManager.default.fileExists(atPath: keyURL.path))
    }

    func testSaveCertificate() throws {
        let testData = Data("test certificate data".utf8)

        try Configuration.saveCertificate(testData)

        // Verify it was saved
        let savedData = try Configuration.readCertificate()
        XCTAssertEqual(savedData, testData, "Saved certificate should match original data")

        // Clean up
        Configuration.deleteCertificates()
    }

    func testSavePrivateKey() throws {
        let testData = Data("test private key data".utf8)

        try Configuration.savePrivateKey(testData)

        // Verify it was saved
        let savedData = try Configuration.readPrivateKey()
        XCTAssertEqual(savedData, testData, "Saved private key should match original data")

        // Clean up
        Configuration.deleteCertificates()
    }

    func testReadNonexistentCertificate() {
        // Clean up any existing certificates
        Configuration.deleteCertificates()

        // Try to read non-existent certificate
        XCTAssertThrowsError(try Configuration.readCertificate()) { error in
            XCTAssertTrue(error is CocoaError, "Should throw CocoaError for missing file")
        }
    }

    func testReadNonexistentPrivateKey() {
        // Clean up any existing certificates
        Configuration.deleteCertificates()

        // Try to read non-existent private key
        XCTAssertThrowsError(try Configuration.readPrivateKey()) { error in
            XCTAssertTrue(error is CocoaError, "Should throw CocoaError for missing file")
        }
    }

    func testHasCertificatesWhenBothExist() throws {
        // Create both certificate files
        let certData = Data("cert".utf8)
        let keyData = Data("key".utf8)

        try Configuration.saveCertificate(certData)
        try Configuration.savePrivateKey(keyData)

        // Check that hasCertificates returns true
        XCTAssertTrue(Configuration.hasCertificates(), "Should return true when both certificates exist")

        // Clean up
        Configuration.deleteCertificates()
    }

    func testHasCertificatesWhenOnlyOneExists() throws {
        // Create only certificate (not key)
        let certData = Data("cert".utf8)
        try Configuration.saveCertificate(certData)

        // Should return false because both are needed
        XCTAssertFalse(Configuration.hasCertificates(), "Should return false when only one certificate exists")

        // Clean up
        Configuration.deleteCertificates()
    }

    // MARK: - File Path Tests

    func testConfigDirectory() {
        let dir = Configuration.configDirectory
        XCTAssertNotNil(dir, "Config directory should not be nil")
        XCTAssertTrue(dir.hasDirectoryPath || dir.path.hasSuffix("/"), "Should be a directory path")
    }

    func testFileURLs() {
        let envURL = Configuration.envFileURL
        let certURL = Configuration.certFileURL
        let keyURL = Configuration.keyFileURL

        XCTAssertTrue(envURL.path.hasSuffix(".env"), "Env URL should end with .env")
        XCTAssertTrue(certURL.path.hasSuffix(".shield_cert.pem"), "Cert URL should end with .shield_cert.pem")
        XCTAssertTrue(keyURL.path.hasSuffix(".shield_key.pem"), "Key URL should end with .shield_key.pem")
    }

    // MARK: - Edge Cases

    func testSaveEmptyConfiguration() throws {
        let config = Configuration()
        // Should not throw even with nil host
        XCTAssertNoThrow(try config.save())

        // Clean up
        try? FileManager.default.removeItem(at: Configuration.envFileURL)
    }

    func testConfigurationWithWhitespace() throws {
        // Create .env with whitespace
        let envContent = "  SHIELD_HOST  =  192.168.1.100  \n"
        let envURL = Configuration.envFileURL
        try envContent.write(to: envURL, atomically: true, encoding: .utf8)

        let config = Configuration.load()
        // Should handle whitespace correctly
        XCTAssertEqual(config.shieldHost, "192.168.1.100", "Should trim whitespace from config values")

        // Clean up
        try? FileManager.default.removeItem(at: envURL)
    }

    func testConfigurationWithComments() throws {
        // Create .env with comments
        let envContent = """
        # This is a comment
        SHIELD_HOST=192.168.1.100
        # Another comment
        """
        let envURL = Configuration.envFileURL
        try envContent.write(to: envURL, atomically: true, encoding: .utf8)

        let config = Configuration.load()
        XCTAssertEqual(config.shieldHost, "192.168.1.100", "Should ignore comments")

        // Clean up
        try? FileManager.default.removeItem(at: envURL)
    }

    func testConfigurationWithEmptyLines() throws {
        // Create .env with empty lines
        let envContent = """

        SHIELD_HOST=192.168.1.100

        """
        let envURL = Configuration.envFileURL
        try envContent.write(to: envURL, atomically: true, encoding: .utf8)

        let config = Configuration.load()
        XCTAssertEqual(config.shieldHost, "192.168.1.100", "Should handle empty lines")

        // Clean up
        try? FileManager.default.removeItem(at: envURL)
    }
}
