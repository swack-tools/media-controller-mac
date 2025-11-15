# MediaControl

> macOS menu bar app for controlling your Nvidia Shield TV and Onkyo/Integra AV receiver with global hotkeys

Control your home theater setup directly from your Mac's menu bar with convenient keyboard shortcuts. MediaControl provides unified control for Nvidia Shield TV playback and Onkyo/Integra receiver volume/mute functions.

<p align="center">
  <img src="https://img.shields.io/badge/platform-macOS%2013.0+-blue" alt="Platform">
  <img src="https://img.shields.io/badge/swift-5.0-orange" alt="Swift">
  <img src="https://img.shields.io/badge/version-1.3.0-brightgreen" alt="Version">
  <img src="https://img.shields.io/badge/license-MIT-green" alt="License">
</p>

## ⌨️ Keyboard Shortcuts

| Hotkey | Action | Device |
|--------|--------|--------|
| **Command+;** | Cycle listening modes | Receiver |
| **Command+F8** | Play/Pause | Shield TV |
| **F10** | Mute toggle | Receiver + System |
| **F11** | Volume down | Receiver + System |
| **F12** | Volume up | Receiver + System |

> 💡 All shortcuts work globally across macOS - no need to switch to MediaControl first!

## ✨ Features

### 🎮 Nvidia Shield TV Control
- **Play/pause media** via Command+F8
- Secure pairing using Android TV Remote Protocol v2
- TLS-encrypted communication with client certificates
- Credentials stored securely in macOS Keychain

### 🔊 Onkyo/Integra Receiver Control
- **Command+;**: Cycle through listening modes (Music, TV Logic, Dolby Surround, etc.)
- **F10**: Mute toggle (syncs with system audio)
- **F11**: Volume down (syncs with system volume)
- **F12**: Volume up (syncs with system volume)
- Real-time volume slider with live feedback
- Audio/Video information display with input/output details
- Supports all Onkyo/Integra receivers with eISCP network protocol

### ⚙️ Additional Features
- **Menu bar integration** - Unobtrusive status bar icon
- **Global hotkeys** - Control without switching apps
- **Launch at login** - Automatically start with macOS
- **Independent configuration** - Use one or both devices
- **Network-based** - No physical connections required

## 📋 Requirements

- **macOS 13.0+** (Ventura or later)
- **Network**: Shield TV and/or Onkyo receiver on same network as Mac
- **Accessibility permissions** (for global hotkeys)
- **Build requirements** (for building from source):
  - Xcode 15+
  - [XcodeGen](https://github.com/yonaskolb/XcodeGen): `brew install xcodegen`
  - [Just](https://github.com/casey/just): `brew install just`

## 🚀 Installation

### Option 1: Download Release (Recommended)

1. Download the latest `.dmg` from [Releases](https://github.com/yourusername/media-control/releases)
2. Open the DMG and drag MediaControl to Applications
3. Launch MediaControl
4. Grant Accessibility permissions when prompted

The app is **signed and notarized** by Apple - no security warnings.

### Option 2: Build from Source

```bash
# Clone the repository
git clone https://github.com/yourusername/media-control.git
cd media-control

# Install dependencies
brew install xcodegen just

# Build the app
just build

# Run MediaControl
just run
```

## 🎯 Quick Start

### 1. Initial Setup

After launching, the 🔊 icon appears in your menu bar.

**Configure Shield TV** (optional):
1. Click menu bar icon → **Configure Shield IP...**
2. Enter Shield TV IP address (e.g., `192.168.1.100`)
3. Click **Save**
4. Select **Pair Shield TV...** from menu
5. Enter the 6-digit PIN shown on your TV screen

**Configure Receiver** (optional):
1. Click menu bar icon → **Configure Receiver IP...**
2. Enter receiver IP address (e.g., `192.168.1.50`)
3. Click **Save**

> 💡 Find device IPs in your router's admin panel or device network settings

### 2. Enable Global Hotkeys

To use keyboard shortcuts:

1. Open **System Settings** → **Privacy & Security** → **Accessibility**
2. Click **+** and add **MediaControl**
3. Enable the checkbox next to MediaControl
4. Restart the app

### 3. Start Using

| Hotkey | Action | Device |
|--------|--------|--------|
| **Command+;** | Cycle listening modes | Receiver |
| **Command+F8** | Play/Pause | Shield TV |
| **F10** | Mute toggle | Receiver + System |
| **F11** | Volume down | Receiver + System |
| **F12** | Volume up | Receiver + System |

> ⚠️ F10-F12 control both receiver and Mac system volume to keep them synchronized.
> 💡 Command+; cycles through receiver listening modes (Music, TV Logic, Dolby Surround, etc.)

## 🏗️ Architecture

MediaControl uses a modular Swift Package Manager architecture:

```
media-control/
├── Sources/
│   ├── ShieldClient/          # Android TV Remote Protocol v2
│   │   ├── ShieldClient.swift
│   │   ├── AndroidTVConnection.swift
│   │   ├── ProtobufEncoder.swift
│   │   ├── ShieldRemoteHelpers.swift
│   │   └── CertificateStore.swift
│   │
│   └── OnkyoClient/            # eISCP Protocol
│       ├── OnkyoClient.swift
│       └── OnkyoProtocol.swift
│
├── MediaControlApp/            # macOS App
│   ├── AppDelegate.swift
│   ├── StatusBarController.swift
│   ├── SettingsManager.swift
│   └── NotificationManager.swift
│
├── Tests/                      # Unit Tests
│   ├── ShieldClientTests/
│   └── OnkyoClientTests/
│
├── Package.swift               # SPM manifest
├── project.yml                 # XcodeGen config
└── justfile                    # Build automation
```

### Key Components

#### ShieldClient Library
- Pure Swift implementation of Android TV Remote Protocol v2
- TLS encryption with client certificate authentication
- Custom protobuf message encoder
- Secure certificate storage in macOS Keychain
- Modern async/await API

#### OnkyoClient Library
- Pure Swift eISCP (Integra Serial Control Protocol) implementation
- TCP socket communication on port 60128
- Real-time volume feedback and parsing
- Supports all Onkyo and Integra network receivers

#### MediaControlApp
- NSStatusBar integration for menu bar icon
- CGEvent tap for global hotkey monitoring
- UserDefaults for persistent configuration
- ServiceManagement for launch-at-login

### Security & Privacy

**Certificate Management:**
- Shield TV certificates stored in **macOS Keychain** (not files)
- Encrypted with system-level encryption
- Persists across app updates
- Re-pairing replaces old certificates

**Network Communication:**
- Shield TV: TLS-encrypted on ports 6466-6467
- Onkyo: TCP plaintext on port 60128 (eISCP standard)
- All communication stays on local network
- No external data collection

## 🛠️ Development

### Build Commands

```bash
just build          # Build debug version
just release        # Build release version
just test           # Run all tests
just clean          # Clean build artifacts
just generate       # Generate Xcode project
just open           # Open in Xcode
just run            # Build and run
just kill           # Kill running instances
just lint           # Run SwiftLint (if installed)
just package v1.0.0 # Create versioned DMG
```

### Running Tests

```bash
# Run all tests (47 tests across both libraries)
just test

# Run specific test suite
swift test --filter ShieldClientTests
swift test --filter OnkyoClientTests

# Verbose output
just test-verbose
```

### Creating a Release

```bash
# Local release build and DMG
just package v1.0.0

# Or step-by-step
just release
just create-dmg v1.0.0

# CI/CD release (automatic on git tag)
git tag v1.0.0
git push origin v1.0.0
```

The GitHub Actions workflow automatically:
1. Runs tests
2. Builds release
3. Signs with Apple Developer certificate
4. Notarizes with Apple
5. Creates DMG
6. Publishes GitHub release

## ❓ Troubleshooting

### Shield TV Issues

**"Shield TV: Not paired"**
- Click **Pair Shield TV...** from menu
- Ensure Shield TV is powered on
- Verify same network as Mac
- Check firewall allows ports 6466-6467

**"PIN not appearing on TV"**
- PIN appears after selecting "Pair Shield TV..."
- Wait for dialog prompting for PIN
- PIN shows on TV screen (valid ~30 seconds)
- Re-pairing is safe and replaces old certificate

**"Pairing failed"**
- Enter PIN exactly as shown (case-sensitive)
- Ensure Shield TV is on and network-accessible
- Try pairing again
- Check Console.app for errors (filter: "MediaControl")

### Receiver Issues

**"Receiver: No response"**
- Verify receiver is powered on (not standby)
- Confirm IP address is correct
- Test connectivity: `ping <receiver-ip>`
- Enable network control in receiver settings (if required)

**Volume slider not updating**
- Slider queries receiver when menu opens
- Defaults to 50 if receiver unreachable
- Close and reopen menu to refresh

### Global Hotkeys

**Hotkeys not working**
1. Grant Accessibility permissions: System Settings → Privacy & Security → Accessibility
2. Restart MediaControl after granting permissions
3. Verify no other apps capture same hotkeys
4. Check Console.app for permission errors

**Command+F8 not triggering Shield TV**
- Ensure Shield TV is paired and configured
- Verify network connectivity
- Check pairing status in menu

**F10/F11/F12 not controlling receiver**
- Confirm receiver IP is configured
- Verify receiver is powered on
- These keys also control system volume by design

### General Issues

**App not in menu bar**
- Check Console.app for errors (search "MediaControl")
- Ensure macOS 13.0+
- Rebuild: `just clean && just build`

**"Operation not permitted" errors**
- Grant required permissions in System Settings
- Restart app after permission changes

## 📝 License

MIT License - see [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Android TV Remote Protocol v2 reverse engineering community
- Swift Package Manager and XcodeGen maintainers
- eISCP protocol documentation

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create feature branch (`git checkout -b feature/amazing-feature`)
3. Run tests (`just test`)
4. Commit changes (`git commit -m 'Add amazing feature'`)
5. Push to branch (`git push origin feature/amazing-feature`)
6. Open Pull Request

## 📧 Support

If you encounter issues:

1. Check [Troubleshooting](#-troubleshooting) section
2. Search [GitHub Issues](https://github.com/yourusername/media-control/issues)
3. Open new issue with:
   - macOS version
   - Device models (Shield TV model, receiver model)
   - Steps to reproduce
   - Console.app logs (filter: "MediaControl")

---

**Made with ❤️ for home theater enthusiasts**
