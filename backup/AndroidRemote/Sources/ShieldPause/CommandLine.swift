import ArgumentParser
import Foundation

public struct ShieldPauseCommand: ParsableCommand {
    public static let configuration = CommandConfiguration(
        commandName: "shield-pause",
        abstract: "Send play/pause command to Nvidia Shield TV",
        discussion: """
        This tool connects to an Nvidia Shield TV device and sends a play/pause command.

        On first run, it will prompt for the Shield's IP address and guide you through
        the pairing process. The credentials are saved locally for future use.

        Examples:
          shield-pause                     # Use saved credentials
          shield-pause --host 192.168.1.100  # Override saved IP address
          shield-pause --repair            # Force re-pairing with Shield
        """
    )

    @Option(
        name: .long,
        help: "Shield TV IP address (overrides saved configuration)"
    )
    public var host: String?

    @Flag(
        name: .long,
        help: "Force re-pairing with Shield TV (deletes saved certificates)"
    )
    public var repair: Bool = false

    public init() {}

    public mutating func run() throws {
        // Validate host if provided
        if let host = host {
            guard Validators.isValidIPAddress(host) else {
                throw ValidationError.invalidIPAddress(
                    "'\(host)' is not a valid IP address. Use format: xxx.xxx.xxx.xxx"
                )
            }
        }

        // Execute the main logic
        try runAsync()
    }

    func runAsync() throws {
        let semaphore = DispatchSemaphore(value: 0)
        var executionError: Error?

        Task {
            do {
                try await ShieldRemote.execute(host: host, forceRepair: repair)
                semaphore.signal()
            } catch {
                executionError = error
                semaphore.signal()
            }
        }

        semaphore.wait()

        if let error = executionError {
            throw error
        }
    }
}
