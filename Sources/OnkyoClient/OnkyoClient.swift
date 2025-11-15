import Foundation
import Network

/// Public API for controlling Onkyo/Integra AV Receivers via eISCP protocol
public class OnkyoClient {
    let host: String
    static let defaultPort: UInt16 = 60128
    static let connectionTimeout: TimeInterval = 3.0

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
                return inputSource.isEmpty ? "Unknown" : inputSource
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
                return listeningMode.isEmpty ? "Unknown" : listeningMode
            }
        }
        throw OnkyoClientError.invalidResponse
    }

    /// Query current audio information
    /// - Returns: Array of audio information lines for display
    /// - Throws: OnkyoClientError if query fails
    public func getAudioInformation() async throws -> [String] {
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
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }

            if components.isEmpty {
                return ["No Signal"]
            }
            return parseAudioInfo(components)
        }
        throw OnkyoClientError.invalidResponse
    }

    /// Parse audio information into display lines
    /// - Parameter components: Array of audio info components from receiver
    /// - Returns: Array of formatted lines for display
    private func parseAudioInfo(_ components: [String]) -> [String] {
        // Components format:
        // [0] Input source (e.g., "HDMI 3") - ignore, shown in Input field
        // [1-3] Audio Input: Format, Sample rate, Channels (e.g., "Dolby D +", "48 kHz", "5.1 ch")
        // [4+] Audio Output: Listening mode, Speaker config (e.g., "All Ch Stereo", "5.0.2 ch")

        var lines: [String] = []

        // Build Audio Input section (components 1-3)
        var inputDetails: [String] = []
        if components.count > 1 {
            inputDetails.append(components[1]) // Format (PCM, DTS, Dolby D +, etc.)
        }
        if components.count > 2 {
            inputDetails.append(components[2]) // Sample rate (48 kHz, etc.)
        }
        if components.count > 3 {
            inputDetails.append(components[3]) // Channels (2.0 ch, 5.1 ch, etc.)
        }

        if !inputDetails.isEmpty {
            lines.append("Input: " + inputDetails.joined(separator: ", "))
        }

        // Build Audio Output section (components 4+)
        var outputDetails: [String] = []
        if components.count > 4 {
            for index in 4..<components.count {
                let info = components[index].trimmingCharacters(in: .whitespaces)
                if !info.isEmpty {
                    outputDetails.append(info)
                }
            }
        }

        if !outputDetails.isEmpty {
            lines.append("Output: " + outputDetails.joined(separator: ", "))
        }

        return lines.isEmpty ? ["Unknown"] : lines
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
        // Format: HDMI 3,1920 x 1080p  59 Hz,RGB,24bit,MAIN,1920 x 1080p  59 Hz,RGB,24bit,,
        // [0] = Input port (skip)
        // [1-3] = Video Input: resolution+Hz, color space, bit depth
        // [4] = Mode/marker
        // [5-7] = Video Output: resolution+Hz, color space, bit depth
        let parts = rawInfo.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

        var lines: [String] = []

        // Build Video Input section (components 1-3)
        var inputDetails: [String] = []
        if parts.count > 1 && !parts[1].isEmpty && !parts[1].uppercased().hasPrefix("HDMI") {
            inputDetails.append(parts[1]) // Resolution + Hz
        }
        if parts.count > 2 && !parts[2].isEmpty {
            inputDetails.append(parts[2]) // Color space (RGB, etc.)
        }
        if parts.count > 3 && !parts[3].isEmpty {
            inputDetails.append(parts[3]) // Bit depth (24bit, etc.)
        }

        if !inputDetails.isEmpty {
            lines.append("Input: " + inputDetails.joined(separator: ", "))
        }

        // Build Video Output section (components 5-7, skipping component 4 which is mode/marker)
        var outputDetails: [String] = []
        if parts.count > 5 && !parts[5].isEmpty {
            outputDetails.append(parts[5]) // Resolution + Hz
        }
        if parts.count > 6 && !parts[6].isEmpty {
            outputDetails.append(parts[6]) // Color space (RGB, etc.)
        }
        if parts.count > 7 && !parts[7].isEmpty {
            outputDetails.append(parts[7]) // Bit depth (24bit, etc.)
        }

        if !outputDetails.isEmpty {
            lines.append("Output: " + outputDetails.joined(separator: ", "))
        }

        return lines.isEmpty ? [rawInfo] : lines
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

    func sendCommand(_ command: String, expectingPrefix: String) async throws -> String {
        let packet = buildPacket(for: command)

        return try await withCheckedThrowingContinuation { continuation in
            let resumed = ResumedFlag()
            let queue = DispatchQueue(label: "onkyo.\(UUID().uuidString)")

            let connection = createConnection()

            // Setup read response handler
            let readHandler = createReadHandler(
                connection: connection,
                expectingPrefix: expectingPrefix,
                resumed: resumed,
                continuation: continuation
            )

            // Setup connection state handler
            setupConnectionStateHandler(
                connection: connection,
                packet: packet,
                resumed: resumed,
                continuation: continuation,
                readHandler: readHandler
            )

            connection.start(queue: queue)

            // Setup timeout
            setupTimeout(
                queue: queue,
                connection: connection,
                resumed: resumed,
                continuation: continuation
            )
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
