import Foundation
import ShieldClient
import OnkyoClient

/// Manages app settings and client instances
class SettingsManager {
    // UserDefaults keys
    private enum Keys {
        static let shieldIP = "shieldIPAddress"
        static let receiverIP = "receiverIPAddress"
        static let launchAtLogin = "launchAtLogin"
    }

    // Singleton instance
    static let shared = SettingsManager()

    // Certificate store for Shield TV
    let certificateStore = CertificateStore()

    // MARK: - Settings

    var shieldIP: String? {
        get { UserDefaults.standard.string(forKey: Keys.shieldIP) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.shieldIP)
            updateShieldClient()
        }
    }

    var receiverIP: String? {
        get { UserDefaults.standard.string(forKey: Keys.receiverIP) }
        set {
            UserDefaults.standard.set(newValue, forKey: Keys.receiverIP)
            updateOnkyoClient()
        }
    }

    var launchAtLogin: Bool {
        get { UserDefaults.standard.bool(forKey: Keys.launchAtLogin) }
        set { UserDefaults.standard.set(newValue, forKey: Keys.launchAtLogin) }
    }

    // MARK: - Clients

    private(set) var shieldClient: ShieldClient?
    private(set) var onkyoClient: OnkyoClient?

    private init() {
        // Migrate existing certificate to have proper access control
        // This ensures certificates stored before v1.3.2 get the kSecAttrAccessibleAfterFirstUnlock attribute
        try? certificateStore.migrateCertificateAccessControl()

        // Initialize clients if IPs are configured
        updateShieldClient()
        updateOnkyoClient()
    }

    private func updateShieldClient() {
        if let ipAddress = shieldIP {
            shieldClient = ShieldClient(host: ipAddress, certificateStore: certificateStore)
        } else {
            shieldClient = nil
        }
    }

    private func updateOnkyoClient() {
        if let ipAddress = receiverIP {
            onkyoClient = OnkyoClient(host: ipAddress)
        } else {
            onkyoClient = nil
        }
    }

    // MARK: - Helper Methods

    /// Check if Shield TV is configured and paired
    var isShieldReady: Bool {
        guard let client = shieldClient else { return false }
        return client.isPaired
    }

    /// Check if receiver is configured
    var isReceiverConfigured: Bool {
        return receiverIP != nil
    }
}
