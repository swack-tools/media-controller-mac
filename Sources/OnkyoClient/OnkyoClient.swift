import Foundation
import Network

/// Public API for controlling Onkyo/Integra AV Receivers via eISCP protocol
public class OnkyoClient {
    private let host: String
    private static let defaultPort: UInt16 = 60128
    private static let connectionTimeout: TimeInterval = 3.0

    public init(host: String) {
        self.host = host
    }

    // MARK: - Public API

    /// Query current volume level from receiver
    /// - Returns: Volume level (0-100, maps 1:1 to receiver display)
    /// - Throws: OnkyoClientError if query fails
    public func getVolume() async throws -> Int {
        let response = try await sendCommand("MVLQSTN", expectingPrefix: "MVL")

        // Parse MVL response - format is "!1MVL{hex}\u{1A}\r\n"
        // where {hex} is a 2-digit hex value (e.g., "29" = 0x29 = 41 decimal)
        let cleaned = response.replacingOccurrences(of: "!1", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\u{1A}", with: "")
            .trimmingCharacters(in: .whitespaces)

        if cleaned.hasPrefix("MVL") {
            let hexString = String(cleaned.dropFirst(3)).filter { $0.isHexDigit }
            if let hexValue = Int(hexString, radix: 16) {
                return hexValue
            }
        }
        throw OnkyoClientError.invalidResponse
    }

    /// Set volume to a specific level
    /// - Parameter level: Volume level (0-100)
    /// - Throws: OnkyoClientError if command fails
    public func setVolume(_ level: Int) async throws {
        let clampedVolume = max(0, min(100, level))
        let hexValue = String(format: "%02X", clampedVolume)
        _ = try await sendCommand("MVL\(hexValue)", expectingPrefix: "MVL")
    }

    /// Increase volume by 5 units
    /// - Throws: OnkyoClientError if command fails
    public func volumeUp() async throws {
        _ = try await sendCommand("MVLUP", expectingPrefix: "MVL")
    }

    /// Decrease volume by 5 units
    /// - Throws: OnkyoClientError if command fails
    public func volumeDown() async throws {
        _ = try await sendCommand("MVLDOWN", expectingPrefix: "MVL")
    }

    /// Set mute state
    /// - Parameter enabled: True to mute, false to unmute
    /// - Throws: OnkyoClientError if command fails
    public func setMute(_ enabled: Bool) async throws {
        let command = enabled ? "AMT01" : "AMT00"
        _ = try await sendCommand(command, expectingPrefix: "AMT")
    }

    /// Toggle mute on/off
    /// - Throws: OnkyoClientError if command fails
    public func toggleMute() async throws {
        // Query current mute state, then toggle
        let currentState = try await isMuted()
        try await setMute(!currentState)
    }

    /// Power off the receiver
    /// - Throws: OnkyoClientError if command fails
    public func powerOff() async throws {
        _ = try await sendCommand("PWR00", expectingPrefix: "PWR")
    }

    /// Power on the receiver
    /// - Throws: OnkyoClientError if command fails
    public func powerOn() async throws {
        _ = try await sendCommand("PWR01", expectingPrefix: "PWR")
    }

    /// Set listening mode to Music
    /// - Throws: OnkyoClientError if command fails
    public func setMusicMode() async throws {
        _ = try await sendCommand("LMD0C", expectingPrefix: "LMD")
    }

    /// Query current mute state
    /// - Returns: True if muted, false otherwise
    /// - Throws: OnkyoClientError if query fails
    public func isMuted() async throws -> Bool {
        let response = try await sendCommand("AMTQSTN", expectingPrefix: "AMT")

        let cleaned = response.replacingOccurrences(of: "!1", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\u{1A}", with: "")
            .trimmingCharacters(in: .whitespaces)

        // AMT01 = muted, AMT00 = unmuted
        return cleaned.contains("AMT01")
    }

    // MARK: - Private Implementation

    private func sendCommand(_ command: String, expectingPrefix: String) async throws -> String {
        let packet = buildPacket(for: command)

        return try await withCheckedThrowingContinuation { continuation in
            var resumed = false
            let queue = DispatchQueue(label: "onkyo.\(UUID().uuidString)")

            let connection = NWConnection(
                host: NWEndpoint.Host(host),
                port: NWEndpoint.Port(integerLiteral: Self.defaultPort),
                using: .tcp
            )

            // Recursive read function - receiver may send multiple responses
            // (e.g., album art data before volume response)
            func readNextResponse() {
                // Read eISCP header (16 bytes)
                connection.receive(minimumIncompleteLength: 16, maximumLength: 16) { headerData, _, _, headerError in
                    guard headerError == nil, let headerData = headerData, headerData.count == 16 else {
                        if !resumed {
                            resumed = true
                            connection.cancel()
                            continuation.resume(throwing: OnkyoClientError.connectionFailed("Header read failed"))
                        }
                        return
                    }

                    // Parse data size from header (bytes 8-11, big-endian UInt32)
                    let dataSize = headerData[8..<12].withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }

                    // Read message data
                    let dataLength = Int(dataSize)
                    connection.receive(
                        minimumIncompleteLength: dataLength,
                        maximumLength: dataLength
                    ) { messageData, _, _, messageError in
                        guard messageError == nil, let messageData = messageData,
                              let responseString = String(data: messageData, encoding: .utf8) else {
                            if !resumed {
                                resumed = true
                                connection.cancel()
                                continuation.resume(throwing: OnkyoClientError.invalidResponse)
                            }
                            return
                        }

                        // Check if this response contains the expected prefix
                        if responseString.contains(expectingPrefix) {
                            if !resumed {
                                resumed = true
                                connection.cancel()
                                continuation.resume(returning: responseString)
                            }
                        } else {
                            // Not the response we want - read next message
                            readNextResponse()
                        }
                    }
                }
            }

            connection.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    connection.send(content: packet, completion: .contentProcessed { error in
                        if let error = error {
                            if !resumed {
                                resumed = true
                                connection.cancel()
                                let failureError = OnkyoClientError.connectionFailed(
                                    error.localizedDescription
                                )
                                continuation.resume(throwing: failureError)
                            }
                        } else {
                            readNextResponse()
                        }
                    })
                case .failed(let error), .waiting(let error):
                    if !resumed {
                        resumed = true
                        connection.cancel()
                        let failureError = OnkyoClientError.connectionFailed(
                            error.localizedDescription
                        )
                        continuation.resume(throwing: failureError)
                    }
                default:
                    break
                }
            }

            connection.start(queue: queue)

            // Timeout handler
            queue.asyncAfter(deadline: .now() + Self.connectionTimeout) {
                if !resumed {
                    resumed = true
                    connection.cancel()
                    continuation.resume(throwing: OnkyoClientError.timeout)
                }
            }
        }
    }

    private func buildPacket(for command: String) -> Data {
        var packet = Data()
        let message = "!1\(command)\r\n"
        let messageData = message.data(using: .utf8)!
        let dataSize = UInt32(messageData.count)
        let headerSize: UInt32 = 16

        // eISCP packet structure:
        // "ISCP" magic (4 bytes)
        packet.append(contentsOf: "ISCP".utf8)

        // Header size: 16 (4 bytes, big-endian)
        packet.append(contentsOf: [
            UInt8((headerSize >> 24) & 0xFF), UInt8((headerSize >> 16) & 0xFF),
            UInt8((headerSize >> 8) & 0xFF), UInt8(headerSize & 0xFF)
        ])

        // Data size (4 bytes, big-endian)
        packet.append(contentsOf: [
            UInt8((dataSize >> 24) & 0xFF), UInt8((dataSize >> 16) & 0xFF),
            UInt8((dataSize >> 8) & 0xFF), UInt8(dataSize & 0xFF)
        ])

        // Version: 0x01, Reserved: 0x00 0x00 0x00
        packet.append(contentsOf: [0x01, 0x00, 0x00, 0x00])

        // Message data
        packet.append(messageData)

        return packet
    }
}

// MARK: - Public Error Type

public enum OnkyoClientError: LocalizedError {
    case connectionFailed(String)
    case invalidResponse
    case timeout

    public var errorDescription: String? {
        switch self {
        case .connectionFailed(let message):
            return "Receiver: \(message)"
        case .invalidResponse:
            return "Receiver: Unexpected response"
        case .timeout:
            return "Receiver: No response. Is device on?"
        }
    }
}
