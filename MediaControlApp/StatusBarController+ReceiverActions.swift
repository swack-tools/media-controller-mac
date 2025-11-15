import Cocoa
import OnkyoClient

// MARK: - Receiver Actions

extension StatusBarController {
    @objc func volumeUp() {
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

    @objc func volumeDown() {
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

    @objc func toggleMute() {
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

    @objc func receiverPowerOn() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    NotificationManager.shared.showError(device: "Receiver", message: "Not configured")
                    return
                }
                try await client.powerOn()
                NotificationManager.shared.showSuccess(device: "Receiver", message: "Power on sent")
            } catch {
                NotificationManager.shared.showError(device: "Receiver", message: error.localizedDescription)
            }
        }
    }

    @objc func receiverPowerOff() {
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

    @objc func setMusicMode() {
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

    @objc func volumeSliderChanged() {
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

    @objc func configureReceiverIP() {
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

    // MARK: - Display Updates

    func updateVolumeDisplay() {
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

    func updateInputSourceDisplay() {
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

    func updateListeningModeDisplay() {
        Task {
            do {
                guard let client = settings.onkyoClient else {
                    audioModeLabel.title = "Mode: --"
                    return
                }
                let listeningMode = try await retryQuery {
                    try await client.getListeningMode()
                }
                DispatchQueue.main.async {
                    self.audioModeLabel.title = "Mode: \(listeningMode)"
                }
            } catch {
                DispatchQueue.main.async {
                    self.audioModeLabel.title = "Mode: --"
                }
            }
        }
    }
}
