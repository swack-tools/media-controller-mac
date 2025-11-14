import Foundation

/// Minimal Protocol Buffers encoder for Android TV Remote Protocol
/// Implements just what we need - KISS principle
struct ProtobufEncoder {

    // MARK: - Wire Types

    private enum WireType: UInt8 {
        case varint = 0           // int32, int64, uint32, uint64, sint32, sint64, bool, enum
        case fixed64 = 1          // fixed64, sfixed64, double
        case lengthDelimited = 2  // string, bytes, embedded messages, packed repeated fields
        case startGroup = 3       // groups (deprecated)
        case endGroup = 4         // groups (deprecated)
        case fixed32 = 5          // fixed32, sfixed32, float
    }

    // MARK: - Encoding Methods

    /// Encode a field tag (field number + wire type)
    private static func encodeTag(fieldNumber: UInt32, wireType: WireType) -> [UInt8] {
        let tag = (fieldNumber << 3) | UInt32(wireType.rawValue)
        return encodeVarint(tag)
    }

    /// Encode a varint (variable-length integer)
    fileprivate static func encodeVarint(_ value: UInt32) -> [UInt8] {
        var result: [UInt8] = []
        var val = value

        while val >= 0x80 {
            result.append(UInt8((val & 0x7F) | 0x80))
            val >>= 7
        }
        result.append(UInt8(val & 0x7F))

        return result
    }

    /// Encode a string field
    static func encodeString(fieldNumber: UInt32, value: String) -> Data {
        var data = Data()
        let stringBytes = value.utf8

        // Tag (field number + wire type)
        data.append(contentsOf: encodeTag(fieldNumber: fieldNumber, wireType: .lengthDelimited))

        // Length
        data.append(contentsOf: encodeVarint(UInt32(stringBytes.count)))

        // Value
        data.append(contentsOf: stringBytes)

        return data
    }

    /// Encode a bytes field
    static func encodeBytes(fieldNumber: UInt32, value: [UInt8]) -> Data {
        var data = Data()

        // Tag
        data.append(contentsOf: encodeTag(fieldNumber: fieldNumber, wireType: .lengthDelimited))

        // Length
        data.append(contentsOf: encodeVarint(UInt32(value.count)))

        // Value
        data.append(contentsOf: value)

        return data
    }

    /// Encode a uint32 field
    static func encodeUInt32(fieldNumber: UInt32, value: UInt32) -> Data {
        var data = Data()

        // Tag
        data.append(contentsOf: encodeTag(fieldNumber: fieldNumber, wireType: .varint))

        // Value
        data.append(contentsOf: encodeVarint(value))

        return data
    }

    /// Encode an embedded message
    static func encodeMessage(fieldNumber: UInt32, value: Data) -> Data {
        var data = Data()

        // Tag
        data.append(contentsOf: encodeTag(fieldNumber: fieldNumber, wireType: .lengthDelimited))

        // Length
        data.append(contentsOf: encodeVarint(UInt32(value.count)))

        // Value
        data.append(value)

        return data
    }
}

// MARK: - Android TV Protocol Messages

/// Protocol message builders for Android TV Remote Protocol v2
@available(macOS 13.0, *)
struct AndroidTVMessages {

    /// Create a pairing request message
    /// Matches working Swift implementation from AndroidTVRemoteControl:
    ///   OuterMessage {
    ///     field 2: status = 200 (OK)
    ///     field 1: protocol_version = 2
    ///     field 10: payload = PairingRequest {
    ///       field 1: service_name (string)
    ///       field 2: client_name (string)
    ///     }
    ///   }
    static func createPairingRequest(clientName: String, serviceName: String) -> Data {
        var message = Data()

        // Field 2: status = 200 (OK)
        // Encoded as: 0x10 (field 2 tag), 0xc8, 0x01 (varint 200)
        message.append(contentsOf: [0x10, 0xc8, 0x01])

        // Field 1: protocol_version = 2
        // Encoded as: 0x08 (field 1 tag), 0x02 (value 2)
        message.append(contentsOf: [0x08, 0x02])

        // Build inner PairingRequest message
        var innerMessage = Data()

        // Field 1: service_name
        if !serviceName.isEmpty {
            innerMessage.append(0x0a)  // Field 1 tag
            innerMessage.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(serviceName.utf8.count)))
            innerMessage.append(contentsOf: serviceName.utf8)
        }

        // Field 2: client_name
        if !clientName.isEmpty {
            innerMessage.append(0x12)  // Field 2 tag
            innerMessage.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(clientName.utf8.count)))
            innerMessage.append(contentsOf: clientName.utf8)
        }

        // Field 10: payload (length-delimited)
        message.append(0x52)  // Field 10 tag (10 << 3 | 2 = 82 = 0x52)
        message.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(innerMessage.count)))
        message.append(innerMessage)

        return message
    }

    /// Create an options request message
    /// Matches working Swift implementation:
    ///   OuterMessage {
    ///     field 1: protocol_version = 2
    ///     field 2: status = 200 (OK)
    ///     field 20: ParingOption {
    ///       field 2: output_encodings = [ParingEncoding {
    ///         field 1: type = 0 (hexadecimal)
    ///         field 2: symbol_length = 6
    ///       }]
    ///       field 3: preferred_role = 1 (input)
    ///     }
    ///   }
    static func createOptionsRequest() -> Data {
        var message = Data()

        // Field 1: protocol_version = 2
        message.append(contentsOf: [0x08, 0x02])

        // Field 2: status = 200 (OK)
        message.append(contentsOf: [0x10, 0xc8, 0x01])

        // Build ParingOption inner message
        var optionMessage = Data()

        // Build ParingEncoding for output
        var encodingData = Data()
        encodingData.append(0x08)  // Field 1: type
        encodingData.append(0x00)  // hexadecimal = 0
        encodingData.append(0x10)  // Field 2: symbol_length
        encodingData.append(0x06)  // 6 characters

        // Field 2: output_encodings (repeated, length-delimited)
        optionMessage.append(0x12)  // Field 2 tag
        optionMessage.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(encodingData.count)))
        optionMessage.append(encodingData)

        // Field 3: preferred_role = 1 (input)
        optionMessage.append(0x18)  // Field 3 tag
        optionMessage.append(0x01)  // Value = 1 (input role)

        // Field 20: options payload
        message.append(contentsOf: [0xa2, 0x01])  // Field 20 tag
        message.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(optionMessage.count)))
        message.append(optionMessage)

        return message
    }

    /// Create a configuration request message
    /// Matches working Swift implementation:
    ///   OuterMessage {
    ///     field 1: protocol_version = 2
    ///     field 2: status = 200 (OK)
    ///     field 30: ParingConfiguration {
    ///       field 1: encoding (with type from Shield's options response)
    ///       field 2: client_role = 1 (input)
    ///     }
    ///   }
    static func createConfigurationRequest(encodingType: UInt8 = 0) -> Data {
        var message = Data()

        // Field 1: protocol_version = 2
        message.append(contentsOf: [0x08, 0x02])

        // Field 2: status = 200 (OK)
        message.append(contentsOf: [0x10, 0xc8, 0x01])

        // Build ParingConfiguration inner message
        var configMessage = Data()

        // Build ParingEncoding object using Shield's preferred encoding type
        var encodingData = Data()
        encodingData.append(0x08)  // Field 1: type
        encodingData.append(encodingType)  // Use Shield's preferred type (from options response)
        encodingData.append(0x10)  // Field 2: symbol_length
        encodingData.append(0x06)  // 6 characters

        // Field 1: encoding (length-delimited ParingEncoding object)
        configMessage.append(0x0a)  // Field 1 tag
        configMessage.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(encodingData.count)))
        configMessage.append(encodingData)

        // Field 2: client_role = 1 (input)
        configMessage.append(0x10)  // Field 2 tag
        configMessage.append(0x01)  // Value = 1 (input role)

        // Field 30: configuration payload
        message.append(contentsOf: [0xf2, 0x01])  // Field 30 tag
        message.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(configMessage.count)))
        message.append(configMessage)

        return message
    }

    /// Create a secret message (PIN verification)
    /// Matches working Swift implementation:
    ///   OuterMessage {
    ///     field 1: protocol_version = 2
    ///     field 2: status = 200 (OK)
    ///     field 40: PairingSecret {
    ///       field 1: secret (bytes) - SHA256 hash of certs + PIN
    ///     }
    ///   }
    static func createSecretMessage(secret: [UInt8]) -> Data {
        var message = Data()

        // Field 1: protocol_version = 2
        message.append(contentsOf: [0x08, 0x02])

        // Field 2: status = 200 (OK)
        message.append(contentsOf: [0x10, 0xc8, 0x01])

        // Build PairingSecret payload
        var secretPayload = Data()
        // Field 1: secret (bytes)
        secretPayload.append(ProtobufEncoder.encodeBytes(fieldNumber: 1, value: secret))

        // Field 40: secret payload (continuing the pattern 10, 20, 30, 40)
        // Field 40 tag = (40 << 3) | 2 = 322 = varint [0xc2, 0x02]
        message.append(contentsOf: [0xc2, 0x02])  // Field 40 tag
        message.append(contentsOf: ProtobufEncoder.encodeVarint(UInt32(secretPayload.count)))
        message.append(secretPayload)

        return message
    }

    /// Create a remote set active message
    /// RemoteMessage {
    ///   field 2: RemoteSetActive {
    ///     field 1: active (int32) - active features
    ///   }
    /// }
    static func createRemoteSetActiveMessage() -> Data {
        // Build RemoteSetActive
        var setActive = Data()

        // Field 1: active (feature flags)
        // Feature flags: PING=1, KEY=2, POWER=32, VOLUME=64, APP_LINK=512
        // Using PING | KEY | POWER | VOLUME | APP_LINK = 611
        setActive.append(ProtobufEncoder.encodeUInt32(fieldNumber: 1, value: 611))

        // Wrap in RemoteMessage at field 2
        return ProtobufEncoder.encodeMessage(fieldNumber: 2, value: setActive)
    }

    /// Create a configuration response for the remote control port
    /// RemoteMessage {
    ///   field 1: RemoteConfigure {
    ///     field 1: code1 (int32) - active features
    ///     field 2: RemoteDeviceInfo {
    ///       field 3: unknown1 (int32) = 1
    ///       field 4: unknown2 (string) = "1"
    ///       field 5: package_name (string)
    ///       field 6: app_version (string)
    ///     }
    ///   }
    /// }
    static func createRemoteConfigureMessage() -> Data {
        // Build RemoteDeviceInfo
        var deviceInfo = Data()

        // Field 3: unknown1 = 1
        deviceInfo.append(ProtobufEncoder.encodeUInt32(fieldNumber: 3, value: 1))

        // Field 4: unknown2 = "1"
        deviceInfo.append(ProtobufEncoder.encodeString(fieldNumber: 4, value: "1"))

        // Field 5: package_name
        deviceInfo.append(ProtobufEncoder.encodeString(fieldNumber: 5, value: "ShieldPause"))

        // Field 6: app_version
        deviceInfo.append(ProtobufEncoder.encodeString(fieldNumber: 6, value: "1.0.0"))

        // Build RemoteConfigure
        var remoteConfigure = Data()

        // Field 1: code1 (active features)
        // Feature flags: PING=1, KEY=2, POWER=32, VOLUME=64, APP_LINK=512
        // Using PING | KEY | POWER | VOLUME | APP_LINK = 1 | 2 | 32 | 64 | 512 = 611
        remoteConfigure.append(ProtobufEncoder.encodeUInt32(fieldNumber: 1, value: 611))

        // Field 2: device_info
        remoteConfigure.append(ProtobufEncoder.encodeMessage(fieldNumber: 2, value: deviceInfo))

        // Wrap in RemoteMessage at field 1
        return ProtobufEncoder.encodeMessage(fieldNumber: 1, value: remoteConfigure)
    }

    /// Create a key press message
    /// RemoteMessage {
    ///   field 10: RemoteKeyInject {
    ///     field 1: key_code (int32)
    ///     field 2: direction (int32) - 1=DOWN, 2=UP, 3=SHORT
    ///   }
    /// }
    static func createKeyPressMessage(keyCode: UInt32, direction: UInt32 = 3) -> Data {
        var keyPressMessage = Data()

        // Build inner RemoteKeyInject message
        // Field 1: key_code
        keyPressMessage.append(ProtobufEncoder.encodeUInt32(fieldNumber: 1, value: keyCode))

        // Field 2: direction (3 = SHORT press)
        keyPressMessage.append(ProtobufEncoder.encodeUInt32(fieldNumber: 2, value: direction))

        // Wrap in RemoteMessage at field 10
        return ProtobufEncoder.encodeMessage(fieldNumber: 10, value: keyPressMessage)
    }
}
