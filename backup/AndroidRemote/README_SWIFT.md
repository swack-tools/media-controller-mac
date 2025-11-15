# Shield Pause CLI (Swift Version)

A Swift command-line tool to control Nvidia Shield TV playback using the Android TV Remote Protocol v2.

This is a Swift port of the Python `pause.py` script.

## Current Status

✅ **Completed:**
- Project structure created with XcodeGen support
- Swift Package Manager configuration
- Command-line argument parsing (using swift-argument-parser)
- Configuration management (.env file handling)
- IP address and PIN validation
- Shield TV remote control logic (using AndroidTVRemoteControl library)
- Main entry point and async execution
- .gitignore for sensitive files

⚠️ **Known Issues:**
1. **AndroidTVRemoteControl Library Compilation Errors:**
   - The library has macOS availability issues (checks for iOS 14.0 but not macOS versions)
   - APIs like `SecTrustCopyKey`, `NWConnection`, etc. are available in macOS 11.0+
   - Our deployment target is macOS 13.0, so all APIs should be available
   - **Solution needed:** Fork the library and add proper macOS availability annotations

2. **Certificate Format:**
   - Python version uses PEM certificates (.shield_cert.pem, .shield_key.pem)
   - Swift AndroidTVRemoteControl library expects P12/PKCS#12 format
   - PEM to P12 conversion logic partially implemented
   - **Temporary workaround:** Use Python script to generate certificates first

## Project Structure

```
swift/
├── project.yml                    # XcodeGen configuration
├── Package.swift                  # Swift Package Manager manifest
├── Sources/
│   └── ShieldPause/
│       ├── main.swift            # Entry point
│       ├── ShieldRemote.swift    # Main remote control logic
│       ├── Configuration.swift   # Config & certificate management
│       ├── CommandLine.swift     # Argument parsing
│       └── Validators.swift      # IP & PIN validation
├── .env                          # Configuration storage (gitignored)
├── .shield_cert.pem             # Certificate (gitignored)
├── .shield_key.pem              # Private key (gitignored)
├── .gitignore                   # Sensitive file exclusions
├── README.md                    # Python version documentation
└── README_SWIFT.md              # This file (Swift version)
```

## Dependencies

- **AndroidTVRemoteControl** (v1.3.5) - Android TV Remote Protocol v2 implementation
  - GitHub: https://github.com/odyshewroman/AndroidTVRemoteControl
  - ⚠️ Has macOS compatibility issues that need to be resolved
- **swift-argument-parser** (v1.6.2) - Apple's CLI argument parsing library

## Building (Once Issues are Fixed)

### Using Swift Package Manager (Recommended)

```bash
# Build
swift build -c release

# Run
.build/release/ShieldPause

# Or directly
swift run ShieldPause
```

### Using XcodeGen and Xcode

```bash
# Install XcodeGen (if not installed)
brew install xcodegen

# Generate Xcode project
xcodegen generate

# Open in Xcode
open ShieldPause.xcodeproj

# Build from command line
xcodebuild -project ShieldPause.xcodeproj -scheme ShieldPause -configuration Release
```

## Usage (Planned)

Once the build issues are resolved:

```bash
# First run - will prompt for IP and guide through pairing
shield-pause

# Use specific IP address
shield-pause --host 192.168.1.100

# Force re-pairing with Shield
shield-pause --repair
```

## Next Steps to Complete the Conversion

### Option 1: Fix the AndroidTVRemoteControl Library (Recommended)

1. **Fork the library:**
   ```bash
   # Fork https://github.com/odyshewroman/AndroidTVRemoteControl
   ```

2. **Add macOS availability annotations:**

   In `CertManager.swift` (line 48):
   ```swift
   // Change from:
   if #available(iOS 14.0, *) {
       guard let key = SecTrustCopyKey(secTrust) else {

   // To:
   if #available(iOS 14.0, macOS 11.0, *) {
       guard let key = SecTrustCopyKey(secTrust) else {
   ```

   In `TLSManager.swift` and other files using Network framework:
   ```swift
   // Add macOS 10.14 availability to Network API calls
   if #available(iOS 13.0, macOS 10.14, *) {
       // Network API calls
   }
   ```

3. **Update Package.swift to use your fork:**
   ```swift
   .package(url: "https://github.com/YOUR_USERNAME/AndroidTVRemoteControl", from: "1.3.5"),
   ```

### Option 2: Implement PEM to P12 Conversion

Complete the `createCFArrayFromPEM` method in `ShieldRemote.swift`:
- Use Security framework to convert PEM to P12
- Generate SecIdentity from PEM certificate and private key
- Return CFArray format expected by TLSManager

### Option 3: Use Python for Certificate Generation

Workflow:
1. Run Python `pause.py` once to generate certificates
2. Use Swift version with existing certificates
3. Swift version reads `.shield_cert.pem` and `.shield_key.pem`

### Option 4: Implement Protocol from Scratch

Implement Android TV Remote Protocol v2 directly in Swift without the library dependency:
- Pros: Full control, no external dependency issues
- Cons: Significant development effort
- Reference: https://github.com/Aymkdn/assistant-freebox-cloud/wiki/Google-TV-(aka-Android-TV)-Remote-Control-(v2)

## Technical Details

### Android TV Remote Protocol v2

**Pairing Port:** 6467
1. Connect with TLS
2. Send pairing request (client name, service name)
3. Receive pairing response
4. Send option request
5. Receive option response
6. Send configuration request
7. Receive configuration response (TV shows PIN)
8. User enters PIN
9. Send secret (hashed PIN + certificates)
10. Receive secret response (success/failure)

**Remote Port:** 6466
1. Connect with TLS using paired certificates
2. Send/receive configuration messages
3. Send key commands (KEYCODE_MEDIA_PLAY_PAUSE = 85)

### Certificate Management

**Python (androidtvremote2):**
- Auto-generates self-signed RSA 2048-bit certificate
- Stores as PEM files (.shield_cert.pem, .shield_key.pem)
- Uses OpenSSL under the hood

**Swift (AndroidTVRemoteControl):**
- Expects P12/PKCS#12 or SecCertificate/SecKey objects
- Uses Security framework
- Needs manual certificate generation or conversion

## Comparison with Python Version

| Feature | Python | Swift | Status |
|---------|--------|-------|--------|
| Configuration management | ✅ | ✅ | Complete |
| IP validation | ✅ | ✅ | Complete |
| PIN validation | ✅ | ✅ | Complete |
| Certificate persistence | ✅ PEM | ⚠️ Needs P12 | Format conversion needed |
| Pairing flow | ✅ | ⚠️ | Logic complete, library has build errors |
| Command sending | ✅ | ⚠️ | Logic complete, library has build errors |
| Error handling | ✅ | ✅ | Complete |
| Command-line args | ✅ | ✅ | Complete |
| Build status | ✅ Works | ❌ Compilation errors | Library compatibility issue |

## Build Errors Summary

The AndroidTVRemoteControl library has macOS availability issues:

```
error: 'SecTrustCopyKey' is only available in macOS 11.0 or newer
error: 'NWProtocolTLS' is only available in macOS 10.14 or newer
error: 'NWConnection' is only available in macOS 10.14 or newer
... (and more Network framework APIs)
```

**Root Cause:** Library checks `#available(iOS 14.0, *)` but doesn't include macOS versions.

**Fix:** Add macOS version annotations: `#available(iOS 14.0, macOS 11.0, *)`

## Contributing

To complete this conversion, contributions needed:
1. ✅ Fork AndroidTVRemoteControl library
2. ✅ Add proper macOS `@available` annotations
3. ⬜ Test with actual Shield TV device
4. ⬜ Implement/test PEM to P12 conversion
5. ⬜ Add unit tests

## References

- **Android TV Remote Protocol v2:**
  https://github.com/Aymkdn/assistant-freebox-cloud/wiki/Google-TV-(aka-Android-TV)-Remote-Control-(v2)
- **AndroidTVRemoteControl Library:**
  https://github.com/odyshewroman/AndroidTVRemoteControl
- **Python androidtvremote2:**
  https://github.com/tronikos/androidtvremote2
- **Swift Argument Parser:**
  https://github.com/apple/swift-argument-parser

## License

Same as the original Python script.
