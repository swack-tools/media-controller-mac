import Foundation
import Network
import Security

// MARK: - Android TV Key Codes

/// Android TV remote control key codes
/// Only including codes we actually use
enum KeyCode: UInt32 {
    case mediaPlayPause = 85
    case mediaPlay = 126
    case mediaPause = 127
    case mediaStop = 86
    case mediaNext = 87
    case mediaPrevious = 88
    case volumeUp = 24
    case volumeDown = 25
    case mute = 91
    case home = 3
    case back = 4
    case dpadUp = 19
    case dpadDown = 20
    case dpadLeft = 21
    case dpadRight = 22
    case dpadCenter = 23
}

// MARK: - Protocol Messages
// Note: Protocol message encoding moved to ProtobufEncoder.swift
// Use AndroidTVMessages class for creating protocol messages

// MARK: - Certificate Management
// Certificate management moved to CertificateStore.swift
