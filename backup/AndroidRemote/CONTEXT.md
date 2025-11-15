# Shield Pause Swift CLI - Context

**Status:** ✅ COMPLETE AND FULLY FUNCTIONAL

## Quick Summary

Fully working Swift CLI that controls Nvidia Shield TV via Android TV Remote Protocol v2. Implements complete pairing handshake and reliable remote control commands.

**Key Achievement:** 14 bugs fixed through systematic debugging, resulting in a production-ready tool with zero external protocol library dependencies.

## Project Overview

Swift CLI application that controls Nvidia Shield TV playback using Android TV Remote Protocol v2. Converted from Python reference implementation.

**Key Directive:** KISS (Keep It Simple Stupid) - Minimal dependencies, hand-coded protobuf encoder, no external protocol libraries.

## Current Status

### Completed ✅

1. **Project Structure**
   - Swift Package Manager setup (Package.swift)
   - XcodeGen configuration (project.yml)
   - Just task automation (justfile with 30+ recipes)
   - Proper target split (ShieldPauseCore library + ShieldPause executable for testing)

2. **Core Implementation**
   - Certificate generation and management (P12 format with password "shield")
   - TLS connection using Network framework (NWConnection, NWProtocolTLS)
   - Configuration management (.env file, certificate files)
   - IP and PIN validation
   - 35 passing tests (100% success rate)

3. **Protocol Implementation**
   - Minimal hand-coded protobuf encoder (no external dependencies)
   - Proper message framing with varint length prefixes
   - Correct OuterMessage wrapper structure for pairing protocol
   - Complete 3-message pairing handshake implementation

### ✅ **FULLY FUNCTIONAL** ✅

**All features working:**
1. ✅ Complete pairing protocol (port 6467) with 4-message handshake
2. ✅ Play/pause command (port 6466) with RemoteSetActive handshake
3. ✅ Certificate generation and persistent storage
4. ✅ All 35 tests passing
5. ✅ Reliable command execution (tested multiple times)

The CLI successfully pairs with Nvidia Shield TV and can reliably send play/pause commands!

## Technical Details

### Android TV Remote Protocol v2 Structure

**Message Framing:**
- Varint length prefix before each message
- Must read length first, then exact number of bytes

**OuterMessage Structure (Pairing):**
```
Field 1: protocol_version = 2 (0x08, 0x02)
Field 2: status (0x10, 0xc8, 0x01 = 200 OK)
Field 10/20/30: payload (varies by message type)
```

**Pairing Handshake Messages:**

1. **PairingRequest** (Field 10):
```swift
10 c8 01 08 02 52 1d 0a 09 53 68 69 65 6c 64 20 54 56 12 10 53 68 69 65 6c 64 20 50 61 75 73 65 20 43 4c 49
// Status 200, Protocol v2, Field 10 payload with service_name + client_name
```

2. **OptionsRequest** (Field 20):
```swift
08 02 10 c8 01 a2 01 08 12 04 08 00 10 06 18 01
// Protocol v2, Status 200, Field 20 with ParingEncoding object
// ParingEncoding: type=0 (hex), symbol_length=6, preferred_role=1 (input)
```

3. **ConfigurationRequest** (Field 30):
```swift
08 02 10 c8 01 f2 01 06 0a 04 08 00 10 06 10 01
// Protocol v2, Status 200, Field 30 with ParingEncoding + client_role
// NEW: Sends complete ParingEncoding object (4 bytes) instead of incomplete (2 bytes)
```

**ParingEncoding Object:**
```
Field 1 (0x08): type (0=hexadecimal, 3=QR code)
Field 2 (0x10): symbol_length (6 for 6-char PIN)
```

4. **SecretMessage** (Field 40):
```swift
08 02 10 c8 01 ca 02 22 0a 20 b0 3a 6c...
// Protocol v2, Status 200, Field 40 with PairingSecret
// PairingSecret contains SHA256 hash (32 bytes)
// Pattern continues: 10, 20, 30, 40
```

**RemoteMessage Structure (Command Port 6466):**

1. **RemoteConfigure** (Field 1):
```swift
0a 1e 08 e3 04 12 19 18 01 22 01 31 2a 0b 53 68 69 65 6c 64 50 61 75 73 65 32 05 31 2e 30 2e 30
// Field 1: RemoteConfigure
//   Field 1: code1 = 611 (feature flags: PING|KEY|POWER|VOLUME|APP_LINK)
//   Field 2: RemoteDeviceInfo
//     Field 3: unknown1 = 1
//     Field 4: unknown2 = "1"
//     Field 5: package_name = "ShieldPause"
//     Field 6: app_version = "1.0.0"
```

2. **RemoteKeyInject** (Field 10):
```swift
52 04 08 55 10 03
// Field 10: RemoteKeyInject
//   Field 1: key_code = 85 (KEYCODE_MEDIA_PLAY_PAUSE)
//   Field 2: direction = 3 (SHORT press)
```

**Secret Hash Algorithm (from working Swift implementation):**
```swift
// PIN format: 6 hex characters → 3 bytes
// Example: "4B5FFC" → [0x4B, 0x5F, 0xFC]

// Hash components:
// 1. Client certificate RSA modulus (256 bytes)
// 2. Client certificate RSA exponent (3 bytes: 0x01 0x00 0x01)
// 3. Server certificate RSA modulus (256 bytes)
// 4. Server certificate RSA exponent (3 bytes: 0x01 0x00 0x01)
// 5. PIN bytes 2-3 (2 bytes: 0x5F 0xFC)

secret = SHA256(client_mod + client_exp + server_mod + server_exp + PIN[1] + PIN[2])

// Validation: secret[0] should equal PIN[0]
// Example: If PIN[0] = 0x4B, then secret[0] should also be 0x4B
```

**RSA Component Extraction:**
```swift
// Get public key data from SecCertificate
let keyData = SecKeyCopyExternalRepresentation(publicKey)

// For 2048-bit RSA keys, keyData is 270 bytes:
// - 8 bytes: header
// - 257 bytes: modulus (with leading 0x00)
// - 2 bytes: padding
// - 3 bytes: exponent

// Extraction:
modulus = keyData[8..<(keyData.count - 5)]  // Skip 8, take all except last 5
if modulus[0] == 0x00 && modulus.count >= 257:
    modulus = modulus[1..<modulus.count]  // Remove leading null → 256 bytes

exponent = keyData[(keyData.count - 3)..<keyData.count]  // Last 3 bytes
```

### Key Files

**Sources/ShieldPause/**
- `main.swift` - Entry point
- `CommandLine.swift` - Argument parsing (ArgumentParser)
- `Configuration.swift` - .env and certificate file management
- `Validators.swift` - IP and PIN validation
- `AndroidTVProtocol.swift` - Key codes, certificate generation/loading
- `AndroidTVConnection.swift` - TLS connection, message framing
- `ProtobufEncoder.swift` - Minimal protobuf encoder + AndroidTVMessages
- `ShieldRemote.swift` - Main pairing and command logic

**Tests/ShieldPauseTests/**
- `BasicTests.swift` - 8 infrastructure tests
- `ValidatorsTests.swift` - 8 validation tests
- `ConfigurationTests.swift` - 19 config tests

## Learnings from Working Implementations

### Source: odyshewroman/AndroidTVRemoteControl (Swift)

**Critical Insights:**
1. Message structure: Status BEFORE protocol_version in OuterMessage
2. Field numbers: 10 (pairing), 20 (options), 30 (configuration)
3. ParingEncoding must be complete object, not just raw values
4. Symbol length is required for the Shield to know PIN format

### Source: tronikos/androidtvremote2 (Python)

**Protocol Flow:**
1. PairingRequest → pairing_request_ack
2. OptionsRequest → options response
3. ConfigurationRequest → configuration_ack
4. **THEN** PIN appears on TV
5. SecretMessage with SHA256(client_cert + server_cert + PIN)

## Critical Bugs Fixed (Session 1 - Complete Implementation)

### 11. Secret Message Structure - Wrong Field Numbers
- **Error:** Used fields 3 & 4 (message_type + payload) for SecretMessage
- **Root Cause:** Didn't follow the established OuterMessage pattern
- **Fix:** Use field 40 (following pattern: 10, 20, 30, 40) with status field
- **Pattern:** All pairing messages use: protocol_version (field 1) + status (field 2) + payload (field 10/20/30/40)
- **Result:** Pairing now succeeds! Status changed from 400 to 200
- **Location:** ProtobufEncoder.swift:createSecretMessage

### 12. RemoteDeviceInfo - Wrong Field Numbers
- **Error:** Used fields 4 & 5 for package_name and app_version
- **Root Cause:** Missed required unknown1 and unknown2 fields
- **Fix:** Complete DeviceInfo structure:
  - Field 3: unknown1 = 1
  - Field 4: unknown2 = "1"
  - Field 5: package_name
  - Field 6: app_version
- **Result:** Shield stopped sending remote_error, but still rejected
- **Location:** ProtobufEncoder.swift:createRemoteConfigureMessage

### 13. Feature Flags - Invalid Code
- **Error:** Used code1 = 257 (invalid feature combination)
- **Root Cause:** Made up number instead of using proper feature flags
- **Fix:** Use code1 = 611 = PING(1) | KEY(2) | POWER(32) | VOLUME(64) | APP_LINK(512)
- **Feature Enum:**
  - PING = 2^0 = 1
  - KEY = 2^1 = 2
  - IME = 2^2 = 4
  - VOICE = 2^3 = 8
  - UNKNOWN_1 = 2^4 = 16
  - POWER = 2^5 = 32
  - VOLUME = 2^6 = 64
  - APP_LINK = 2^9 = 512
- **Result:** Shield accepted configuration, but commands still didn't work
- **Location:** ProtobufEncoder.swift:createRemoteConfigureMessage

### 14. RemoteSetActive Response - Missing Handshake
- **Error:** Received remote_set_active (field 2) message but ignored it
- **Root Cause:** Didn't realize Shield requires response before accepting commands
- **Observation:** Follow-up changed from remote_error (field 3) to remote_set_active (field 2)
- **Fix:** Detect remote_set_active message and respond with our active features (611)
- **Implementation:**
  ```swift
  if setActiveMsg[0] == 0x12 { // Field 2 = remote_set_active
      let setActiveResponse = AndroidTVMessages.createRemoteSetActiveMessage()
      try await connection.sendMessage(setActiveResponse)
  }
  ```
- **Result:** Play/pause commands now work reliably! Can pause and play repeatedly
- **Location:** ProtobufEncoder.swift:createRemoteSetActiveMessage, ShieldRemote.swift:sendPlayPause

## Errors Fixed (Previous Sessions)

### 1. IP Validator Bug
- **Error:** `split(separator:)` drops empty subsequences
- **Fix:** Use `components(separatedBy:)` + empty check
- **Location:** Validators.swift:isValidIPAddress

### 2. Certificate Loading (OSStatus -50)
- **Error:** Tried to load PKCS#1/8 format as raw key
- **Fix:** Generate and load P12 format using SecPKCS12Import
- **Location:** AndroidTVProtocol.swift:loadIdentity

### 3. Certificate Password Mismatch (Status -25293)
- **Error:** Empty password vs "shield" password
- **Fix:** Use consistent password "shield" in generation and import
- **Location:** AndroidTVProtocol.swift:generateSelfSignedCertificate

### 4. Message Framing
- **Error:** Only reading first byte (length prefix)
- **Fix:** Implement proper varint length reading + full message read
- **Location:** AndroidTVConnection.swift:receiveMessage

### 5. Wrong OuterMessage Structure
- **Error:** Using field 3 (message_type) + field 4 (payload)
- **Fix:** Status (field 2) + Protocol (field 1) + Field 10/20/30 (payload)
- **Location:** ProtobufEncoder.swift:createPairingRequest

### 6. Options Message - Incomplete Encoding
- **Error:** Sending just encoding type (0x00)
- **Fix:** Send complete ParingEncoding object with type + symbol_length
- **Location:** ProtobufEncoder.swift:createOptionsRequest

### 7. Configuration Message - Incomplete Encoding
- **Error:** Sending raw bytes instead of structured object
- **Fix:** Send complete ParingEncoding object (4 bytes: type + symbol_length)
- **Location:** ProtobufEncoder.swift:createConfigurationRequest

### 8. Configuration Message - Hardcoded Encoding Type
- **Error:** Shield returned status 400 with hardcoded encoding type=0
- **Root Cause:** Shield preferred encoding type=3 (QR code), but we sent type=0
- **Fix:** Parse Shield's preferred encoding from options response, use it in configuration
- **Result:** Configuration accepted (status 200), PIN appears on TV
- **Location:** ShieldRemote.swift:pair, ProtobufEncoder.swift:createConfigurationRequest

### 9. Server Certificate Capture
- **Error:** Server certificate was nil when creating secret hash
- **Fix:** Capture server certificate from TLS metadata during connection
- **Implementation:** Use `sec_protocol_metadata_access_peer_certificate_chain` callback
- **Location:** AndroidTVConnection.swift:connect

### 10. RSA Component Extraction
- **Error:** Hashing full certificate DER data instead of RSA components
- **Root Cause:** Working Swift implementation uses RSA modulus + exponent, not certificate data
- **Fix:** Extract RSA public key components using SecKeyCopyExternalRepresentation
- **Algorithm:**
  - Skip first 8 bytes (header)
  - Take everything except last 5 bytes for modulus
  - Remove leading null byte if modulus >= 257 bytes
  - Last 3 bytes are exponent
- **Result:** Correct extraction (256B modulus, 3B exponent 0x010001)
- **Status:** Extraction works, but hash still doesn't match (status 400)
- **Location:** ShieldRemote.swift:extractRSAComponents

## Future Enhancements

1. **Additional Commands** - Extend beyond play/pause
   - Volume up/down
   - Navigation (up, down, left, right, select)
   - Home, back buttons
   - Power on/off
   - All key codes already defined in KeyCode enum

2. **Command-line options** - More flexible control
   - `--command <keycode>` - Send any key code
   - `--verbose` - Show debug output
   - Support for key sequences

3. **Installation** - System-wide availability
   - `just install` to copy to /usr/local/bin
   - Add to PATH for easy access
   - Create shell completions

## Commands

```bash
# Build
just build

# Test (all 35 tests pass)
just test

# Run pairing
just run --host 192.168.1.238 --repair

# Install to system
just install
```

## Git Status

**Branch:** main
**Recent Commits:**
- 571bd5d: fix: implement persistent certificate storage
- d525e71: fix: use correct synchronous method names
- c665f1c: fix: correct PIN format to 6-character hex
- 3ac0420: fix: pair before connecting
- d8c920f: fix: let library create cert files from scratch

**Current Changes:**
- Complete protobuf implementation with minimal hand-coded encoder
- Working 3-message pairing handshake (all accepted, PIN displays)
- Server certificate capture from TLS metadata
- RSA component extraction (modulus + exponent) from certificates
- Dynamic encoding type negotiation with Shield TV
- Secret hash implementation (still debugging verification failure)
- All 35 tests passing

## References

- [AndroidTVRemoteControl Swift](https://github.com/odyshewroman/AndroidTVRemoteControl) - Working implementation
- [androidtvremote2 Python](https://github.com/tronikos/androidtvremote2) - Protocol reference
- [Android TV Remote Protocol v2](https://github.com/tronikos/androidtvremote2/blob/main/src/androidtvremote2/remotemessage.proto)

## Dependencies

- **ArgumentParser** - CLI argument parsing (only external dependency)
- **Foundation** - Standard library
- **Network** - TLS connections
- **Security** - Certificate management
- **CryptoKit** - SHA256 hashing

## Project Stats

- **Total Swift Files:** 7 source files + 3 test files
- **Lines of Code:** ~580 lines (vs 3400+ in Python + library)
- **Test Coverage:** 35 tests, 100% passing
- **Build Time:** ~0.5-1s incremental
- **Binary Size:** TBD (not yet installed)
