import Cocoa
import Carbon

// MARK: - Global Hotkeys

extension StatusBarController {
    func setupGlobalHotkeys() {
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

        NSLog("StatusBarController: Global hotkeys enabled (Command+;, Command+F7/F8/F9, F10/F11/F12)")
    }

    func handleMediaKey(
        proxy: CGEventTapProxy,
        type: CGEventType,
        event: CGEvent
    ) -> Unmanaged<CGEvent>? {
        // Re-enable tap if it was disabled
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            NSLog("StatusBarController: Event tap was disabled, re-enabling...")
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return Unmanaged.passRetained(event)
        }

        // Handle Command+; for Music Mode and Command+F7/F8/F9 for Shield TV controls
        if type == .keyDown {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags

            // Check for Command modifier and semicolon key (keycode 41)
            if flags.contains(.maskCommand) && keyCode == 41 {
                NSLog("StatusBarController: Command+; (Music Mode) detected")
                setMusicMode()
                // Don't pass through to system - consume the event
                return nil
            }

            // Check for Command modifier and F7 key (keycode 98)
            if flags.contains(.maskCommand) && keyCode == 98 {
                NSLog("StatusBarController: Command+F7 (Shield Rewind) detected")
                shieldRewind()
                // Don't pass through to system - consume the event
                return nil
            }

            // Check for Command modifier and F8 key (keycode 100)
            if flags.contains(.maskCommand) && keyCode == 100 {
                NSLog("StatusBarController: Command+F8 (Shield Play/Pause) detected")
                shieldPlayPause()
                // Don't pass through to system - consume the event
                return nil
            }

            // Check for Command modifier and F9 key (keycode 101)
            if flags.contains(.maskCommand) && keyCode == 101 {
                NSLog("StatusBarController: Command+F9 (Shield Fast Forward) detected")
                shieldFastForward()
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
                    return handleMediaKeyPress(keyCode: keyCode, event: event)
                }
            }
        }

        // Always pass through the event so system volume also changes
        return Unmanaged.passRetained(event)
    }

    private func handleMediaKeyPress(keyCode: Int, event: CGEvent) -> Unmanaged<CGEvent>? {
        switch keyCode {
        case 20: // F7/Previous media key - only with Command modifier
            let flags = event.flags
            if flags.contains(.maskCommand) {
                NSLog("StatusBarController: Command+F7 (Shield Rewind) detected")
                shieldRewind()
                // Don't pass through - consume the event
                return nil
            }

        case 16: // F8/Play-Pause media key - only with Command modifier
            let flags = event.flags
            if flags.contains(.maskCommand) {
                NSLog("StatusBarController: Command+F8 (Shield Play/Pause) detected")
                shieldPlayPause()
                // Don't pass through - consume the event
                return nil
            }

        case 19: // F9/Next media key - only with Command modifier
            let flags = event.flags
            if flags.contains(.maskCommand) {
                NSLog("StatusBarController: Command+F9 (Shield Fast Forward) detected")
                shieldFastForward()
                // Don't pass through - consume the event
                return nil
            }

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

        return Unmanaged.passRetained(event)
    }

    func showAccessibilityAlert() {
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
