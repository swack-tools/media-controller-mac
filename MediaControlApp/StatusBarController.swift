import Cocoa
import Carbon
import ServiceManagement
import ShieldClient
import OnkyoClient

class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var menu: NSMenu!
    private var volumeSlider: NSSlider!
    private var volumeLabel: NSMenuItem!
    private var inputSourceLabel: NSMenuItem!
    private var videoInfoLabels: [NSMenuItem] = []
    private var listeningModeLabel: NSMenuItem!
    private var muteItem: NSMenuItem!
    private var launchAtLoginItem: NSMenuItem!
    private var eventTap: CFMachPort?

    private let settings = SettingsManager.shared

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

    private func setupMenuBar() {
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
        menu.addItem(NSMenuItem.sectionHeader(title: "Shield TV"))

        let powerOnItem = NSMenuItem(title: "⚡️ Power On", action: #selector(shieldPowerOn), keyEquivalent: "")
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

        // Separator
        menu.addItem(NSMenuItem.separator())

        // Receiver section
        menu.addItem(NSMenuItem.sectionHeader(title: "Receiver"))

        // Volume label
        volumeLabel = NSMenuItem(title: "Volume: --", action: nil, keyEquivalent: "")
        volumeLabel.isEnabled = false
        menu.addItem(volumeLabel)

        // Volume slider
        setupVolumeSlider()

        // Input source label
        inputSourceLabel = NSMenuItem(title: "Input: --", action: nil, keyEquivalent: "")
        inputSourceLabel.isEnabled = false
        menu.addItem(inputSourceLabel)

        // Video information labels (multi-line, added dynamically)
        // Placeholder will be replaced on menu open

        // Listening mode label
        listeningModeLabel = NSMenuItem(title: "Mode: --", action: nil, keyEquivalent: "")
        listeningModeLabel.isEnabled = false
        menu.addItem(listeningModeLabel)

        let volumeUpItem = NSMenuItem(title: "Volume Up (+5)", action: #selector(volumeUp), keyEquivalent: "")
        volumeUpItem.target = self
        menu.addItem(volumeUpItem)

        let volumeDownItem = NSMenuItem(title: "Volume Down (-5)", action: #selector(volumeDown), keyEquivalent: "")
        volumeDownItem.target = self
        menu.addItem(volumeDownItem)

        muteItem = NSMenuItem(title: "🔇 Mute", action: #selector(toggleMute), keyEquivalent: "")
        muteItem.target = self
        menu.addItem(muteItem)

        let receiverPowerOffItem = NSMenuItem(
            title: "🔴 Power Off",
            action: #selector(receiverPowerOff),
            keyEquivalent: ""
        )
        receiverPowerOffItem.target = self
        menu.addItem(receiverPowerOffItem)

        let musicModeItem = NSMenuItem(title: "🎵 Music Mode", action: #selector(setMusicMode), keyEquivalent: "")
        musicModeItem.target = self
        menu.addItem(musicModeItem)

        // Separator
        menu.addItem(NSMenuItem.separator())

        let configReceiverItem = NSMenuItem(
            title: "Configure Receiver IP...",
            action: #selector(configureReceiverIP),
            keyEquivalent: ""
        )
        configReceiverItem.target = self
        menu.addItem(configReceiverItem)

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

        sliderView.addSubview(volumeSlider)

        let sliderItem = NSMenuItem()
        sliderItem.view = sliderView
        menu.addItem(sliderItem)
    }

    private func setupDPadControl() {
        // Create container view for D-pad with keyboard event handling
        let dpadView = DPadView(frame: NSRect(x: 0, y: 0, width: 240, height: 140))
        dpadView.controller = self

        let buttonSize: CGFloat = 32
        let centerX: CGFloat = 120
        let centerY: CGFloat = 70
        let spacing: CGFloat = 36

        // Up button - aligned with center button
        let upButton = createDPadButton(
            frame: NSRect(
                x: centerX - buttonSize/2,
                y: centerY + spacing - buttonSize/2,
                width: buttonSize,
                height: buttonSize
            ),
            title: "▲",
            action: #selector(dpadUpPressed)
        )
        dpadView.addSubview(upButton)

        // Down button
        let downButton = createDPadButton(
            frame: NSRect(
                x: centerX - buttonSize/2,
                y: centerY - spacing - buttonSize/2,
                width: buttonSize,
                height: buttonSize
            ),
            title: "▼",
            action: #selector(dpadDownPressed)
        )
        dpadView.addSubview(downButton)

        // Left button
        let leftButton = createDPadButton(
            frame: NSRect(
                x: centerX - spacing - buttonSize/2,
                y: centerY - buttonSize/2,
                width: buttonSize,
                height: buttonSize
            ),
            title: "◀",
            action: #selector(dpadLeftPressed)
        )
        dpadView.addSubview(leftButton)

        // Right button
        let rightButton = createDPadButton(
            frame: NSRect(
                x: centerX + spacing - buttonSize/2,
                y: centerY - buttonSize/2,
                width: buttonSize,
                height: buttonSize
            ),
            title: "▶",
            action: #selector(dpadRightPressed)
        )
        dpadView.addSubview(rightButton)

        // Center button (OK/Select)
        let centerButton = createDPadButton(
            frame: NSRect(x: centerX - buttonSize/2, y: centerY - buttonSize/2, width: buttonSize, height: buttonSize),
            title: "OK",
            action: #selector(dpadCenterPressed)
        )
        centerButton.bezelStyle = .rounded
        dpadView.addSubview(centerButton)

        // Back button - lower right corner, aligned with down button
        let backButton = createDPadButton(
            frame: NSRect(
                x: centerX + spacing - buttonSize/2,
                y: centerY - spacing - buttonSize/2,
                width: buttonSize,
                height: buttonSize
            ),
            title: "↩",
            action: #selector(dpadBackPressed)
        )
        dpadView.addSubview(backButton)

        let dpadItem = NSMenuItem()
        dpadItem.view = dpadView
        menu.addItem(dpadItem)
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

    // MARK: - Shield TV Actions

    @objc private func shieldPowerOn() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.wakeUp()
                NotificationManager.shared.showSuccess(device: "Shield TV", message: "Power on sent")
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc private func shieldPowerOff() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.powerOff()
                NotificationManager.shared.showSuccess(device: "Shield TV", message: "Power off sent")
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc private func shieldPlayPause() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.playPause()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc fileprivate func dpadUpPressed() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.dpadUp()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc fileprivate func dpadDownPressed() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.dpadDown()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc fileprivate func dpadLeftPressed() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.dpadLeft()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc fileprivate func dpadRightPressed() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.dpadRight()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc fileprivate func dpadCenterPressed() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.dpadCenter()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc fileprivate func dpadBackPressed() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.back()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc private func configureShieldIP() {
        let alert = NSAlert()
        alert.messageText = "Configure Shield TV"
        alert.informativeText = "Enter the IP address of your Shield TV"
        alert.alertStyle = .informational

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.stringValue = settings.shieldIP ?? ""
        inputField.placeholderString = "192.168.1.100"
        alert.accessoryView = inputField

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let ipAddress = inputField.stringValue.trimmingCharacters(in: .whitespaces)
            if Validators.isValidIPAddress(ipAddress) {
                settings.shieldIP = ipAddress
                NotificationManager.shared.showSuccess(device: "Shield TV", message: "IP saved")
            } else {
                NotificationManager.shared.showError(device: "Shield TV", message: "Invalid IP address")
            }
        }
    }

    @objc private func pairShield() {
        // First, ensure IP is configured
        guard let ipAddress = settings.shieldIP else {
            NotificationManager.shared.showError(device: "Shield TV", message: "Configure IP first")
            return
        }

        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }

                // Start pairing with callback for PIN
                try await client.pair {
                    // This callback is called when PIN appears on TV
                    // We need to show the PIN dialog on main thread and wait for user input
                    return try await withCheckedThrowingContinuation { continuation in
                        DispatchQueue.main.async {
                            let alert = NSAlert()
                            alert.messageText = "Enter Pairing PIN"
                            let infoText = "A 6-character PIN should now be displayed on "
                                + "your Shield TV.\nEnter it below:"
                            alert.informativeText = infoText
                            alert.alertStyle = .informational

                            let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
                            inputField.placeholderString = "ABC123"
                            alert.accessoryView = inputField

                            alert.addButton(withTitle: "Pair")
                            alert.addButton(withTitle: "Cancel")

                            let response = alert.runModal()
                            if response == .alertFirstButtonReturn {
                                let pin = inputField.stringValue.trimmingCharacters(in: .whitespaces).uppercased()
                                continuation.resume(returning: pin)
                            } else {
                                let error = NSError(
                                    domain: "PairingCancelled",
                                    code: -1,
                                    userInfo: [NSLocalizedDescriptionKey: "Pairing cancelled by user"]
                                )
                                continuation.resume(throwing: error)
                            }
                        }
                    }
                }

                NotificationManager.shared.showSuccess(device: "Shield TV", message: "Paired successfully!")
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Receiver Actions

    @objc private func volumeUp() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    NotificationManager.shared.showError(device: "Receiver", message: "Not configured")
                    return
                }
                try await client.volumeUp()
                updateVolumeDisplay()
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc private func volumeDown() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    NotificationManager.shared.showError(device: "Receiver", message: "Not configured")
                    return
                }
                try await client.volumeDown()
                updateVolumeDisplay()
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc private func toggleMute() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    NotificationManager.shared.showError(device: "Receiver", message: "Not configured")
                    return
                }
                try await client.toggleMute()
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc private func receiverPowerOff() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    NotificationManager.shared.showError(device: "Receiver", message: "Not configured")
                    return
                }
                try await client.powerOff()
                NotificationManager.shared.showSuccess(device: "Receiver", message: "Power off sent")
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc private func setMusicMode() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    NotificationManager.shared.showError(device: "Receiver", message: "Not configured")
                    return
                }
                try await client.setMusicMode()
                NotificationManager.shared.showSuccess(device: "Receiver", message: "Music mode activated")
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc private func volumeSliderChanged() {
        let volume = Int(volumeSlider.doubleValue)
        volumeLabel.title = "Volume: \(volume)"

        Task {
            do {
                guard let client = settings.onkyoClient else { return }
                try await client.setVolume(volume)
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc private func configureReceiverIP() {
        let alert = NSAlert()
        alert.messageText = "Configure Receiver"
        alert.informativeText = "Enter the IP address of your Onkyo/Integra receiver"
        alert.alertStyle = .informational

        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 200, height: 24))
        inputField.stringValue = settings.receiverIP ?? ""
        inputField.placeholderString = "192.168.1.50"
        alert.accessoryView = inputField

        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Cancel")

        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            let ipAddress = inputField.stringValue.trimmingCharacters(in: .whitespaces)
            if Validators.isValidIPAddress(ipAddress) {
                settings.receiverIP = ipAddress
                NotificationManager.shared.showSuccess(device: "Receiver", message: "IP saved")
                updateVolumeDisplay()
            } else {
                NotificationManager.shared.showError(device: "Receiver", message: "Invalid IP address")
            }
        }
    }

    /// Retry a receiver query with exponential backoff
    /// - Parameters:
    ///   - maxAttempts: Maximum number of attempts (default 5)
    ///   - operation: The async operation to retry
    /// - Returns: Result of the operation
    private func retryQuery<T>(maxAttempts: Int = 5, operation: @escaping () async throws -> T) async throws -> T {
        var lastError: Error?

        for attempt in 1...maxAttempts {
            do {
                return try await operation()
            } catch {
                lastError = error
                if attempt < maxAttempts {
                    // Wait with exponential backoff: 200ms, 400ms, 800ms, 1600ms
                    let delayNs = UInt64(200_000_000 * (1 << (attempt - 1)))
                    try? await Task.sleep(nanoseconds: delayNs)
                }
            }
        }

        throw lastError ?? NSError(domain: "RetryFailed", code: -1)
    }

    private func updateVolumeDisplay() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    volumeLabel.title = "Volume: --"
                    volumeSlider.doubleValue = 50
                    return
                }
                let volume = try await retryQuery {
                    try await client.getVolume()
                }
                DispatchQueue.main.async {
                    self.volumeLabel.title = "Volume: \(volume)"
                    self.volumeSlider.doubleValue = Double(volume)
                }
            } catch {
                DispatchQueue.main.async {
                    self.volumeLabel.title = "Volume: --"
                    self.volumeSlider.doubleValue = 50
                }
            }
        }
    }

    private func updateInputSourceDisplay() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    inputSourceLabel.title = "Input: --"
                    return
                }
                let inputSource = try await retryQuery {
                    try await client.getInputSource()
                }
                DispatchQueue.main.async {
                    self.inputSourceLabel.title = "Input: \(inputSource)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.inputSourceLabel.title = "Input: --"
                }
            }
        }
    }

    private func updateVideoInfoDisplay() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    await clearVideoInfoLabels()
                    await addVideoInfoLabel("Video: --")
                    return
                }
                let videoInfoLines = try await retryQuery {
                    try await client.getVideoInformation()
                }
                DispatchQueue.main.async {
                    // Clear existing video info labels
                    for label in self.videoInfoLabels {
                        self.menu.removeItem(label)
                    }
                    self.videoInfoLabels.removeAll()

                    // Find insertion index (after input source label)
                    guard let inputIndex = self.menu.items.firstIndex(of: self.inputSourceLabel) else {
                        return
                    }
                    let insertIndex = inputIndex + 1

                    // Add new video info labels
                    for (index, line) in videoInfoLines.enumerated() {
                        let label = NSMenuItem(
                            title: index == 0 ? "Video: \(line)" : "  \(line)",
                            action: nil,
                            keyEquivalent: ""
                        )
                        label.isEnabled = false
                        self.menu.insertItem(label, at: insertIndex + index)
                        self.videoInfoLabels.append(label)
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    // Clear existing video info labels
                    for label in self.videoInfoLabels {
                        self.menu.removeItem(label)
                    }
                    self.videoInfoLabels.removeAll()

                    // Find insertion index
                    guard let inputIndex = self.menu.items.firstIndex(of: self.inputSourceLabel) else {
                        return
                    }

                    let label = NSMenuItem(title: "Video: --", action: nil, keyEquivalent: "")
                    label.isEnabled = false
                    self.menu.insertItem(label, at: inputIndex + 1)
                    self.videoInfoLabels.append(label)
                }
            }
        }
    }

    private func clearVideoInfoLabels() async {
        await MainActor.run {
            for label in self.videoInfoLabels {
                self.menu.removeItem(label)
            }
            self.videoInfoLabels.removeAll()
        }
    }

    private func addVideoInfoLabel(_ title: String) async {
        await MainActor.run {
            guard let inputIndex = self.menu.items.firstIndex(of: self.inputSourceLabel) else {
                return
            }
            let label = NSMenuItem(title: title, action: nil, keyEquivalent: "")
            label.isEnabled = false
            self.menu.insertItem(label, at: inputIndex + 1)
            self.videoInfoLabels.append(label)
        }
    }

    private func updateListeningModeDisplay() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    listeningModeLabel.title = "Mode: --"
                    return
                }
                let listeningMode = try await retryQuery {
                    try await client.getListeningMode()
                }
                DispatchQueue.main.async {
                    self.listeningModeLabel.title = "Mode: \(listeningMode)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.listeningModeLabel.title = "Mode: --"
                }
            }
        }
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
        alert.informativeText = "Version 1.0\n\nUnified control for Shield TV and Onkyo receivers"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Global Hotkeys

    private func setupGlobalHotkeys() {
        // Listen for both NSSystemDefined (media keys) and keyDown events
        // NSSystemDefined = 14 (for media keys F10/F11/F12)
        // keyDown for Command+F8
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << 14)

        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { proxy, type, event, refcon in
                let controller = Unmanaged<StatusBarController>.fromOpaque(refcon!).takeUnretainedValue()
                return controller.handleMediaKey(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            showAccessibilityAlert()
            return
        }

        self.eventTap = eventTap
        let runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)

        NSLog("StatusBarController: Global hotkeys enabled (Command+F8, F10/F11/F12)")
    }

    private func handleMediaKey(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("StatusBarController: Event tap was disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Handle Command+F8 for Shield TV play/pause
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Check for Command modifier (0x100000) and F8 key (keycode 100)
            if flags.contains(.maskCommand) && keyCode == 100 {
                NSLog("StatusBarController: Command+F8 (Shield Play/Pause) detected")
                shieldPlayPause()
                // Don't pass through to system - consume the event
                return nil
            }
        }

        // Check if this is a system defined event (type 14 for media keys)
        if type.rawValue == 14 {
            let nsEvent = NSEvent(cgEvent: event)

            // Media keys are subtype 8 (NX_SUBTYPE_AUX_CONTROL_BUTTONS)
            if nsEvent?.subtype == .screenChanged {
                let data = nsEvent?.data1 ?? 0
                let keyCode = ((data & 0xFFFF0000) >> 16)
                let keyFlags = (data & 0x0000FFFF)
                let keyPressed = ((keyFlags & 0xFF00) >> 8) == 0xA

                // Only handle key down events
                if keyPressed {
                    switch keyCode {
                    case 7: // F10 - Mute
                        NSLog("StatusBarController: F10 (Mute) detected")
                        toggleMute()

                    case 1: // F11 - Volume Down
                        NSLog("StatusBarController: F11 (Volume Down) detected")
                        volumeDown()

                    case 0: // F12 - Volume Up
                        NSLog("StatusBarController: F12 (Volume Up) detected")
                        volumeUp()

                    default:
                        break
                    }
                }
            }
        }

        // Always pass through the event so system volume also changes
        return Unmanaged.passRetained(event)
    }

    private func showAccessibilityAlert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Accessibility Permissions Required"
            let infoText = "MediaControl needs Accessibility permissions to enable global hotkeys.\n\n"
                + "Please grant permission in System Settings > Privacy & Security > Accessibility"
            alert.informativeText = infoText
            alert.alertStyle = .warning
            alert.addButton(withTitle: "Open System Settings")
            alert.addButton(withTitle: "Skip")

            if alert.runModal() == .alertFirstButtonReturn {
                let urlString = "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
                if let url = URL(string: urlString) {
                    NSWorkspace.shared.open(url)
                }
            }
        }
    }
}

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update receiver status sequentially to avoid overwhelming the receiver
        updateAllReceiverStatus()
    }

    /// Update all receiver status information sequentially with retries
    private func updateAllReceiverStatus() {
        Task {
            // Query sequentially to avoid overwhelming the receiver with simultaneous requests
            // Each query will retry up to 5 times with exponential backoff
            await updateVolumeDisplayAsync()
            await updateInputSourceDisplayAsync()
            await updateVideoInfoDisplayAsync()
            await updateListeningModeDisplayAsync()
        }
    }

    /// Async version of updateVolumeDisplay for sequential execution
    private func updateVolumeDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await MainActor.run {
                    volumeLabel.title = "Volume: --"
                    volumeSlider.doubleValue = 50
                }
                return
            }
            let volume = try await retryQuery {
                try await client.getVolume()
            }
            await MainActor.run {
                self.volumeLabel.title = "Volume: \(volume)"
                self.volumeSlider.doubleValue = Double(volume)
            }
        } catch {
            await MainActor.run {
                self.volumeLabel.title = "Volume: --"
                self.volumeSlider.doubleValue = 50
            }
        }
    }

    /// Async version of updateInputSourceDisplay for sequential execution
    private func updateInputSourceDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await MainActor.run {
                    inputSourceLabel.title = "Input: --"
                }
                return
            }
            let inputSource = try await retryQuery {
                try await client.getInputSource()
            }
            await MainActor.run {
                self.inputSourceLabel.title = "Input: \(inputSource)"
            }
        } catch {
            await MainActor.run {
                self.inputSourceLabel.title = "Input: --"
            }
        }
    }

    /// Async version of updateVideoInfoDisplay for sequential execution
    private func updateVideoInfoDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await clearVideoInfoLabels()
                await addVideoInfoLabel("Video: --")
                return
            }
            let videoInfoLines = try await retryQuery {
                try await client.getVideoInformation()
            }
            await MainActor.run {
                // Clear existing video info labels
                for label in self.videoInfoLabels {
                    self.menu.removeItem(label)
                }
                self.videoInfoLabels.removeAll()

                // Find insertion index (after input source label)
                guard let inputIndex = self.menu.items.firstIndex(of: self.inputSourceLabel) else {
                    return
                }
                let insertIndex = inputIndex + 1

                // Add new video info labels
                for (index, line) in videoInfoLines.enumerated() {
                    let label = NSMenuItem(
                        title: index == 0 ? "Video: \(line)" : "  \(line)",
                        action: nil,
                        keyEquivalent: ""
                    )
                    label.isEnabled = false
                    self.menu.insertItem(label, at: insertIndex + index)
                    self.videoInfoLabels.append(label)
                }
            }
        } catch {
            await MainActor.run {
                // Clear existing video info labels
                for label in self.videoInfoLabels {
                    self.menu.removeItem(label)
                }
                self.videoInfoLabels.removeAll()

                // Find insertion index
                guard let inputIndex = self.menu.items.firstIndex(of: self.inputSourceLabel) else {
                    return
                }

                let label = NSMenuItem(title: "Video: --", action: nil, keyEquivalent: "")
                label.isEnabled = false
                self.menu.insertItem(label, at: inputIndex + 1)
                self.videoInfoLabels.append(label)
            }
        }
    }

    /// Async version of updateListeningModeDisplay for sequential execution
    private func updateListeningModeDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await MainActor.run {
                    listeningModeLabel.title = "Mode: --"
                }
                return
            }
            let listeningMode = try await retryQuery {
                try await client.getListeningMode()
            }
            await MainActor.run {
                self.listeningModeLabel.title = "Mode: \(listeningMode)"
            }
        } catch {
            await MainActor.run {
                self.listeningModeLabel.title = "Mode: --"
            }
        }
    }
}

// MARK: - NSMenuItem Extensions

extension NSMenuItem {
    static func sectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}

// MARK: - DPadView

class DPadView: NSView {
    weak var controller: StatusBarController?

    override var acceptsFirstResponder: Bool {
        return true
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        // Make this view the first responder when added to window
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard let controller = controller else {
            super.keyDown(with: event)
            return
        }

        // Handle arrow keys and special keys
        switch Int(event.keyCode) {
        case 126: // Up arrow
            controller.dpadUpPressed()
        case 125: // Down arrow
            controller.dpadDownPressed()
        case 123: // Left arrow
            controller.dpadLeftPressed()
        case 124: // Right arrow
            controller.dpadRightPressed()
        case 36, 76: // Return or Enter
            controller.dpadCenterPressed()
        case 51: // Delete/Backspace
            controller.dpadBackPressed()
        default:
            super.keyDown(with: event)
        }
    }
}
