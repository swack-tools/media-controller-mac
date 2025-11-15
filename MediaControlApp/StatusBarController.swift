import Cocoa
import Carbon
import ServiceManagement
import ShieldClient
import OnkyoClient

class StatusBarController: NSObject {
    var statusItem: NSStatusItem!
    var menu: NSMenu!
    var volumeSlider: NSSlider!
    var volumeLabel: NSMenuItem!
    var inputSourceLabel: NSMenuItem!
    var inputSeparator: NSMenuItem!
    var audioSectionLabel: NSMenuItem!
    var audioInfoLabels: [NSMenuItem] = []
    var audioModeLabel: NSMenuItem!
    var audioVideoSeparator: NSMenuItem!
    var videoSectionLabel: NSMenuItem!
    var videoInfoLabels: [NSMenuItem] = []
    var muteItem: NSMenuItem!
    var launchAtLoginItem: NSMenuItem!
    var eventTap: CFMachPort?

    let settings = SettingsManager.shared

    // MARK: - Initialization

    override init() {
        super.init()
        NSLog("StatusBarController: Initializing...")
        setupMenuBar()
        NSLog("StatusBarController: Menu bar setup complete")
        setupGlobalHotkeys()
        NSLog("StatusBarController: Global hotkeys setup complete")
    }

    func cleanup() {
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
    }

    // MARK: - Menu Bar Setup

    func setupMenuBar() {
        NSLog("StatusBarController: Creating status item...")

        // Create status item
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        NSLog("StatusBarController: Status item created: %@", statusItem != nil ? "YES" : "NO")

        if let button = statusItem.button {
            NSLog("StatusBarController: Setting up button...")

            // Use SF Symbol if available (macOS 11+), otherwise use text
            if #available(macOS 11.0, *) {
                let config = NSImage.SymbolConfiguration(pointSize: 16, weight: .regular)
                let symbolImage = NSImage(
                    systemSymbolName: "speaker.wave.2.fill",
                    accessibilityDescription: "MediaControl"
                )
                button.image = symbolImage?.withSymbolConfiguration(config)
                NSLog("StatusBarController: Set SF Symbol image: %@", button.image != nil ? "YES" : "NO")
            }

            // Fallback to text if image didn't load
            if button.image == nil {
                button.title = "🔊"
                NSLog("StatusBarController: Using emoji fallback")
            }
        } else {
            NSLog("StatusBarController: ERROR - No button available!")
        }

        // Create menu
        NSLog("StatusBarController: Creating menu...")
        menu = NSMenu()

        // Shield TV section
        buildShieldTVSection()

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Receiver section
        buildReceiverSection()

        // Launch at login
        launchAtLoginItem = NSMenuItem(
            title: "Launch at Login",
            action: #selector(toggleLaunchAtLogin),
            keyEquivalent: ""
        )
        launchAtLoginItem.target = self
        menu.addItem(launchAtLoginItem)
        updateLaunchAtLoginItem()

        // Separator
        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "About MediaControl", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

        let quitItem = NSMenuItem(title: "Quit MediaControl", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        NSLog("StatusBarController: Assigning menu to status item...")
        statusItem.menu = menu
        NSLog("StatusBarController: Menu assigned. Item count: %d", menu.items.count)

        // Set menu delegate to update volume on open
        menu.delegate = self
        NSLog("StatusBarController: Setup complete!")
    }

    private func buildShieldTVSection() {
        menu.addItem(NSMenuItem.sectionHeader(title: "Shield TV"))

        let powerOnItem = NSMenuItem(title: "🟢 Power On", action: #selector(shieldPowerOn), keyEquivalent: "")
        powerOnItem.target = self
        menu.addItem(powerOnItem)

        let powerOffItem = NSMenuItem(title: "🔴 Power Off", action: #selector(shieldPowerOff), keyEquivalent: "")
        powerOffItem.target = self
        menu.addItem(powerOffItem)

        let playPauseItem = NSMenuItem(title: "⏯ Play/Pause", action: #selector(shieldPlayPause), keyEquivalent: "")
        playPauseItem.target = self
        menu.addItem(playPauseItem)

        // D-pad remote control
        setupDPadControl()

        let configShieldItem = NSMenuItem(
            title: "Configure Shield IP...",
            action: #selector(configureShieldIP),
            keyEquivalent: ""
        )
        configShieldItem.target = self
        menu.addItem(configShieldItem)

        let pairItem = NSMenuItem(title: "Pair Shield TV...", action: #selector(pairShield), keyEquivalent: "")
        pairItem.target = self
        menu.addItem(pairItem)
    }

    private func buildReceiverSection() {
        menu.addItem(NSMenuItem.sectionHeader(title: "Receiver"))

        // Power On
        let receiverPowerOnItem = NSMenuItem(
            title: "🟢 Power On",
            action: #selector(receiverPowerOn),
            keyEquivalent: ""
        )
        receiverPowerOnItem.target = self
        menu.addItem(receiverPowerOnItem)

        // Power Off
        let receiverPowerOffItem = NSMenuItem(
            title: "🔴 Power Off",
            action: #selector(receiverPowerOff),
            keyEquivalent: ""
        )
        receiverPowerOffItem.target = self
        menu.addItem(receiverPowerOffItem)

        // Input source label
        inputSourceLabel = NSMenuItem(title: "Input: --", action: nil, keyEquivalent: "")
        inputSourceLabel.isEnabled = false
        menu.addItem(inputSourceLabel)

        // Separator after Input
        inputSeparator = NSMenuItem.separator()
        menu.addItem(inputSeparator)

        // Audio section header
        audioSectionLabel = NSMenuItem(title: "Audio", action: nil, keyEquivalent: "")
        audioSectionLabel.isEnabled = false
        menu.addItem(audioSectionLabel)

        // Volume label (enabled)
        volumeLabel = NSMenuItem(title: "Volume: --", action: nil, keyEquivalent: "")
        volumeLabel.isEnabled = true
        menu.addItem(volumeLabel)

        // Volume slider
        setupVolumeSlider()

        // Volume Up
        let volumeUpItem = NSMenuItem(title: "Volume Up (+5)", action: #selector(volumeUp), keyEquivalent: "")
        volumeUpItem.target = self
        menu.addItem(volumeUpItem)

        // Volume Down
        let volumeDownItem = NSMenuItem(title: "Volume Down (-5)", action: #selector(volumeDown), keyEquivalent: "")
        volumeDownItem.target = self
        menu.addItem(volumeDownItem)

        // Mute
        muteItem = NSMenuItem(title: "🔇 Mute", action: #selector(toggleMute), keyEquivalent: "")
        muteItem.target = self
        menu.addItem(muteItem)

        // Music Mode
        let musicModeItem = NSMenuItem(title: "🎵 Music Mode", action: #selector(setMusicMode), keyEquivalent: "")
        musicModeItem.target = self
        menu.addItem(musicModeItem)

        // Audio Mode label (single line: "Mode: value")
        audioModeLabel = NSMenuItem(title: "Mode: --", action: nil, keyEquivalent: "")
        audioModeLabel.isEnabled = false
        menu.addItem(audioModeLabel)

        // Separator between Audio and Video
        audioVideoSeparator = NSMenuItem.separator()
        menu.addItem(audioVideoSeparator)

        // Video section header
        videoSectionLabel = NSMenuItem(title: "Video", action: nil, keyEquivalent: "")
        videoSectionLabel.isEnabled = false
        menu.addItem(videoSectionLabel)

        // Separator
        menu.addItem(NSMenuItem.separator())

        let configReceiverItem = NSMenuItem(
            title: "Configure Receiver IP...",
            action: #selector(configureReceiverIP),
            keyEquivalent: ""
        )
        configReceiverItem.target = self
        menu.addItem(configReceiverItem)
    }

    private func setupVolumeSlider() {
        let sliderView = NSView(frame: NSRect(x: 0, y: 0, width: 240, height: 30))

        volumeSlider = NSSlider(
            value: 50,
            minValue: 0,
            maxValue: 100,
            target: self,
            action: #selector(volumeSliderChanged)
        )
        volumeSlider.frame = NSRect(x: 20, y: 5, width: 200, height: 20)
        volumeSlider.isEnabled = true

        sliderView.addSubview(volumeSlider)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        sliderItem.isEnabled = true
        menu.addItem(sliderItem)
    }

    private func setupDPadControl() {
        let dpadView = DPadView(frame: NSRect(x: 0, y: 0, width: 240, height: 140))
        dpadView.controller = self

        addDPadButtons(to: dpadView)

        let dpadItem = NSMenuItem()
        dpadItem.view = dpadView
        menu.addItem(dpadItem)
    }

    private func addDPadButtons(to dpadView: DPadView) {
        let buttonSize: CGFloat = 32
        let centerX: CGFloat = 120
        let centerY: CGFloat = 70
        let spacing: CGFloat = 36

        // Up button
        let upButton = createDPadButton(
            frame: buttonFrame(centerX: centerX, centerY: centerY + spacing, size: buttonSize),
            title: "▲",
            action: #selector(dpadUpPressed)
        )
        dpadView.addSubview(upButton)

        // Down button
        let downButton = createDPadButton(
            frame: buttonFrame(centerX: centerX, centerY: centerY - spacing, size: buttonSize),
            title: "▼",
            action: #selector(dpadDownPressed)
        )
        dpadView.addSubview(downButton)

        // Left button
        let leftButton = createDPadButton(
            frame: buttonFrame(centerX: centerX - spacing, centerY: centerY, size: buttonSize),
            title: "◀",
            action: #selector(dpadLeftPressed)
        )
        dpadView.addSubview(leftButton)

        // Right button
        let rightButton = createDPadButton(
            frame: buttonFrame(centerX: centerX + spacing, centerY: centerY, size: buttonSize),
            title: "▶",
            action: #selector(dpadRightPressed)
        )
        dpadView.addSubview(rightButton)

        // Center button (OK/Select)
        let centerButton = createDPadButton(
            frame: buttonFrame(centerX: centerX, centerY: centerY, size: buttonSize),
            title: "OK",
            action: #selector(dpadCenterPressed)
        )
        centerButton.bezelStyle = .rounded
        dpadView.addSubview(centerButton)

        // Back button
        let backButton = createDPadButton(
            frame: buttonFrame(centerX: centerX + spacing, centerY: centerY - spacing, size: buttonSize),
            title: "↩",
            action: #selector(dpadBackPressed)
        )
        dpadView.addSubview(backButton)
    }

    private func buttonFrame(centerX: CGFloat, centerY: CGFloat, size: CGFloat) -> NSRect {
        return NSRect(x: centerX - size/2, y: centerY - size/2, width: size, height: size)
    }

    private func createDPadButton(frame: NSRect, title: String, action: Selector) -> NSButton {
        let button = NSButton(frame: frame)
        button.title = title
        button.target = self
        button.action = action
        button.bezelStyle = .rounded
        button.font = NSFont.systemFont(ofSize: 14)
        return button
    }

    // MARK: - Helper Methods

    /// Retry a receiver query with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default 7, volume uses 10)
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation
    func retryQuery<T>(maxAttempts: Int = 7, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    // Wait with exponential backoff: 250ms, 500ms, 1000ms, 2000ms, 4000ms, etc.
                    let delayNs = UInt64(250_000_000 * (1 << (attempt - 1)))
                    try? await Task.sleep(nanoseconds: delayNs)
                }
            }
        }

        throw lastError ?? NSError(domain: "RetryFailed", code: -1)
    }

    // MARK: - App Actions

    @objc private func toggleLaunchAtLogin() {
        let newState = !settings.launchAtLogin
        setLaunchAtLogin(newState)
        settings.launchAtLogin = newState
        updateLaunchAtLoginItem()
    }

    private func updateLaunchAtLoginItem() {
        launchAtLoginItem.state = settings.launchAtLogin ? .on : .off
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        let service = SMAppService.mainApp

        do {
            if enabled {
                if service.status == .notRegistered {
                    try service.register()
                }
            } else {
                if service.status == .enabled {
                    try service.unregister()
                }
            }
        } catch {
            NotificationManager.shared.showError(device: "App", message: "Failed to update launch at login")
        }
    }

    @objc private func showAbout() {
        let alert = NSAlert()
        alert.messageText = "MediaControl"

        // Get version from Info.plist
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"

        alert.informativeText = "Version \(version)\n\nUnified control for Shield TV and Onkyo receivers"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
