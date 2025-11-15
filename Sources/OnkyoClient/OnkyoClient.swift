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

    /// Query current input source from audio information
    /// - Returns: Input source name (e.g., "HDMI 3", "Optical", etc.)
    /// - Throws: OnkyoClientError if query fails
    public func getInputSource() async throws -> String {
        let response = try await sendCommand("IFAQSTN", expectingPrefix: "IFA")

        // Parse IFA response - format:
        // "!1IFA{input},{format},{sample rate},{channels},{listening mode},...\u{1A}\r\n"
        // Example: "!1IFAHDMI 3,PCM,48 kHz,2.0 ch,All Ch Stereo,5.0.2 ch,\u{1A}\r\n"
        let cleaned = response.replacingOccurrences(of: "!1", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\u{1A}", with: "")
            .trimmingCharacters(in: .whitespaces)

        if cleaned.hasPrefix("IFA") {
            let infoString = String(cleaned.dropFirst(3))
            let components = infoString.components(separatedBy: ",")

            // Input source is the 1st component (index 0)
            if !components.isEmpty {
                let inputSource = components[0].trimmingCharacters(in: .whitespaces)
                return inputSource.isEmpty ? "Unknown" : truncateString(inputSource, maxLength: 25)
            }
        }
        throw OnkyoClientError.invalidResponse
    }

    /// Query current listening mode from audio information
    /// - Returns: Listening mode name (e.g., "All Ch Stereo", "Music", etc.)
    /// - Throws: OnkyoClientError if query fails
    public func getListeningMode() async throws -> String {
        let response = try await sendCommand("IFAQSTN", expectingPrefix: "IFA")

        // Parse IFA response - format:
        // "!1IFA{input},{format},{sample rate},{channels},{listening mode},...\u{1A}\r\n"
        // Example: "!1IFAHDMI 3,PCM,48 kHz,2.0 ch,All Ch Stereo,5.0.2 ch,\u{1A}\r\n"
        let cleaned = response.replacingOccurrences(of: "!1", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\u{1A}", with: "")
            .trimmingCharacters(in: .whitespaces)

        if cleaned.hasPrefix("IFA") {
            let infoString = String(cleaned.dropFirst(3))
            let components = infoString.components(separatedBy: ",")

            // Listening mode is typically the 5th component (index 4)
            if components.count > 4 {
                let listeningMode = components[4].trimmingCharacters(in: .whitespaces)
                return listeningMode.isEmpty ? "Unknown" : truncateString(listeningMode, maxLength: 25)
            }
        }
        throw OnkyoClientError.invalidResponse
    }

    /// Query current video information
    /// - Returns: Array of video information lines for display
    /// - Throws: OnkyoClientError if query fails
    public func getVideoInformation() async throws -> [String] {
        let response = try await sendCommand("IFVQSTN", expectingPrefix: "IFV")

        // Parse IFV response - format varies by receiver
        // Example: "!1IFV1920x1080p,HDMI\u{1A}\r\n" or "!1IFV1080p\u{1A}\r\n"
        let cleaned = response.replacingOccurrences(of: "!1", with: "")
            .replacingOccurrences(of: "\r", with: "")
            .replacingOccurrences(of: "\n", with: "")
            .replacingOccurrences(of: "\u{1A}", with: "")
            .trimmingCharacters(in: .whitespaces)

        if cleaned.hasPrefix("IFV") {
            let videoInfo = String(cleaned.dropFirst(3)).trimmingCharacters(in: .whitespaces)
            if videoInfo.isEmpty {
                return ["No Signal"]
            }
            return parseVideoInfo(videoInfo)
        }
        throw OnkyoClientError.invalidResponse
    }

    /// Parse video information into display lines
    /// - Parameter rawInfo: Raw video info string from receiver
    /// - Returns: Array of formatted lines for display
    private func parseVideoInfo(_ rawInfo: String) -> [String] {
        // Split by comma to get components
        let parts = rawInfo.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var lines: [String] = []
        var resolution = ""
        var details: [String] = []

        for part in parts {
            // Skip HDMI port information as it's shown in Input field
            // This includes "HDMI", "HDMI 1", "HDMI 2", etc.
            if part.uppercased().hasPrefix("HDMI") {
                continue
            }

            // Parse resolution
            if part.contains("x") {
                // Extract resolution like "1920x1080p" -> "1080p" or "3840x2160p" -> "4K"
                if let match = part.range(of: #"(\d+)x(\d+)([pi]?)"#, options: .regularExpression) {
                    let resString = String(part[match])
                    if resString.contains("3840x2160") || resString.contains("4096x2160") {
                        resolution = "4K" + (resString.hasSuffix("i") ? "i" : "")
                    } else if resString.contains("1920x1080") {
                        resolution = "1080" + (resString.hasSuffix("i") ? "i" : "p")
                    } else if resString.contains("1280x720") {
                        resolution = "720p"
                    } else if resString.contains("2560x1440") {
                        resolution = "1440p"
                    } else {
                        resolution = resString
                    }
                }
            } else if !part.isEmpty {
                // Add other details (HDR, color space, frame rate, etc.)
                details.append(part)
            }
        }

        // Build display lines
        if !resolution.isEmpty {
            lines.append(resolution)
        }

        // Group details into lines of reasonable length
        if !details.isEmpty {
            var currentLine = ""
            for detail in details {
                if currentLine.isEmpty {
                    currentLine = detail
                } else if (currentLine + " " + detail).count <= 30 {
                    currentLine += " " + detail
                } else {
                    lines.append(currentLine)
                    currentLine = detail
                }
            }
            if !currentLine.isEmpty {
                lines.append(currentLine)
            }
        }

        return lines.isEmpty ? [rawInfo] : lines
    }

    /// Truncate string with ellipsis if needed
    /// - Parameters:
    ///   - string: String to truncate
    ///   - maxLength: Maximum length before truncation
    /// - Returns: Truncated string with ellipsis if over maxLength
    private func truncateString(_ string: String, maxLength: Int) -> String {
        if string.count > maxLength {
            let index = string.index(string.startIndex, offsetBy: maxLength - 3)
            return String(string[..<index]) + "..."
        }
        return string
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
