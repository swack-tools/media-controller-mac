# Shield Pause CLI

A lightweight Swift CLI tool for controlling Nvidia Shield TV playback using the Android TV Remote Protocol v2.

## Features

- 🎮 **Remote Control** - Send play/pause commands to Shield TV
- 🔐 **Secure Pairing** - TLS-encrypted communication with certificate-based authentication
- 📦 **Minimal Dependencies** - Only ArgumentParser external dependency
- ⚡ **Fast** - ~0.5s execution time after pairing
- 🧪 **Well Tested** - 35 passing unit tests

## Requirements

- macOS 13.0 or later
- Swift 5.9 or later
- Nvidia Shield TV on the same local network

## Installation

### Quick Start with Just

This project uses [just](https://github.com/casey/just) as a command runner:

```bash
# Install just (if not already installed)
brew install just

# Build the project
just build

# Run tests
just test

# Install to system (optional)
just install
```

### Manual Build

```bash
# Build with Swift Package Manager
swift build

# Run directly
swift run ShieldPause --host <SHIELD_IP>
```

## Usage

### First Run (Pairing)

On first use, you'll need to pair with your Shield TV:

```bash
swift run ShieldPause --host 192.168.1.238 --repair
```

You'll be prompted for a 6-character PIN code that appears on your Shield TV screen (e.g., `4B5FFC`).

Certificates are stored locally in `.shield_cert.pem`, `.shield_key.pem`, and `.shield_cert.p12` for future use.

### Normal Usage

After pairing, simply run:

```bash
swift run ShieldPause --host 192.168.1.238
```

Or if you've saved the host in `.env`:

```bash
swift run ShieldPause
```

### With Just

```bash
# Pair (first time)
just run --repair

# Send play/pause command
just run

# Force re-pairing
just repair
```

## Command Line Options

- `--host <IP>` - Shield TV IP address (e.g., 192.168.1.238)
- `--repair` - Force re-pairing and regenerate certificates

## Configuration

The CLI stores configuration in a `.env` file:

```
SHIELD_HOST=192.168.1.238
```

Certificates are stored in the same directory:
- `.shield_cert.pem` - Client certificate
- `.shield_key.pem` - Private key
- `.shield_cert.p12` - PKCS#12 bundle (used internally)

## Project Structure

```
Sources/ShieldPause/
├── main.swift                 # Entry point
├── CommandLine.swift          # Argument parsing
├── Configuration.swift        # Config & certificate management
├── Validators.swift           # IP & PIN validation
├── AndroidTVProtocol.swift    # Key codes & certificate helpers
├── AndroidTVConnection.swift  # TLS connection & message framing
├── ProtobufEncoder.swift      # Minimal protobuf encoder
└── ShieldRemote.swift         # Pairing & command logic

Tests/ShieldPauseTests/
├── BasicTests.swift           # 8 infrastructure tests
├── ValidatorsTests.swift      # 8 validation tests
└── ConfigurationTests.swift   # 19 config tests
```

## Implementation Details

This implementation uses a minimal hand-coded Protocol Buffers encoder following the KISS principle:

- **Pairing Protocol (Port 6467)**: 4-message handshake
  1. PairingRequest (Field 10)
  2. OptionsRequest (Field 20)
  3. ConfigurationRequest (Field 30)
  4. SecretMessage (Field 40) - SHA256 hash of RSA components + PIN

- **Remote Control (Port 6466)**: Command protocol
  1. RemoteConfigure - Device info and feature flags (611)
  2. RemoteSetActive - Activate connection
  3. RemoteKeyInject - Send key commands

Feature flags: `PING | KEY | POWER | VOLUME | APP_LINK = 611`

## Troubleshooting

### Connection Issues

- **"Cannot connect"** - Verify Shield IP address and network connectivity
- **"Connection timeout"** - Ensure Shield TV is powered on and accessible
- **"Pairing failed"** - Try `--repair` to force re-pairing

### PIN Issues

- **"Invalid PIN format"** - Enter exactly 6 hexadecimal characters (e.g., `4B5FFC`)
- **"PIN rejected"** - Enter PIN quickly before it expires (~2 minutes)

### Command Not Working

- **Play/pause doesn't respond** - Run `--repair` to re-establish pairing
- **First command slow** - Normal behavior, subsequent commands are faster

## Development

```bash
# Run tests
just test
# or
swift test

# Build for release
just build-release
# or
swift build -c release

# Clean build artifacts
just clean
```

## Project Stats

- **Lines of Code**: ~600 Swift (vs 3400+ Python reference implementation)
- **Test Coverage**: 35 tests, 100% passing
- **Build Time**: ~0.5s incremental
- **Dependencies**: ArgumentParser only (Foundation, Network, Security, CryptoKit are stdlib)

## References

- [Android TV Remote Protocol v2](https://github.com/tronikos/androidtvremote2) - Python reference implementation
- [Android TV Remote Control (Swift)](https://github.com/odyshewroman/AndroidTVRemoteControl) - Protocol insights

## License

This project is for personal/educational use. See the Android TV Remote Protocol documentation for protocol details.

---

**Note**: This tool was developed following the KISS (Keep It Simple, Stupid) principle with minimal external dependencies.
