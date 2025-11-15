import Cocoa
import ShieldClient

// MARK: - Shield TV Actions

extension StatusBarController {
    @objc func shieldPowerOn() {
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

    @objc func shieldPowerOff() {
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

    @objc func shieldPlayPause() {
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

    @objc func shieldSkipNext() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.skipNext()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc func shieldSkipPrevious() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.skipPrevious()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc func shieldFastForward() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.fastForward()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc func shieldRewind() {
        Task {
            do {
                guard let client = settings.shieldClient else {
                    NotificationManager.shared.showError(device: "Shield TV", message: "Not configured")
                    return
                }
                try await client.rewind()
            } catch {
                NotificationManager.shared.showError(device: "Shield TV", message: error.localizedDescription)
            }
        }
    }

    @objc func dpadUpPressed() {
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

    @objc func dpadDownPressed() {
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

    @objc func dpadLeftPressed() {
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

    @objc func dpadRightPressed() {
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

    @objc func dpadCenterPressed() {
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

    @objc func dpadBackPressed() {
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

    @objc func configureShieldIP() {
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

    @objc func pairShield() {
        // First, ensure IP is configured
        guard settings.shieldIP != nil else {
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
}
