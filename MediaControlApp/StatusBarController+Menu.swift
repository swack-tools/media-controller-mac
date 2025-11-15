import Cocoa

// MARK: - NSMenuDelegate

extension StatusBarController: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        // Update receiver status sequentially to avoid overwhelming the receiver
        updateAllReceiverStatus()
    }

    /// Update all receiver status information sequentially with retries
    func updateAllReceiverStatus() {
        Task {
            // Give receiver time to be ready before first query
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms initial delay

            // Query sequentially to avoid overwhelming the receiver with simultaneous requests
            // Each query will retry up to 7-10 times with exponential backoff
            // Add delay between queries to prevent overwhelming receiver
            await updateVolumeDisplayAsync()
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms between queries

            await updateInputSourceDisplayAsync()
            try? await Task.sleep(nanoseconds: 200_000_000)

            await updateAudioInfoDisplayAsync()
            try? await Task.sleep(nanoseconds: 200_000_000)

            await updateVideoInfoDisplayAsync()
            try? await Task.sleep(nanoseconds: 200_000_000)

            await updateListeningModeDisplayAsync()
        }
    }

    /// Async version of updateVolumeDisplay for sequential execution
    func updateVolumeDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await MainActor.run {
                    volumeLabel.title = "Volume: --"
                    volumeSlider.doubleValue = 50
                }
                return
            }
            // Volume query gets extra retries (10 instead of 7) as it's most critical
            let volume = try await retryQuery(maxAttempts: 10) {
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
    func updateInputSourceDisplayAsync() async {
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

    /// Async version of updateAudioInfoDisplay for sequential execution
    func updateAudioInfoDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await clearAudioInfoLabels()
                return
            }
            let audioInfoLines = try await retryQuery {
                try await client.getAudioInformation()
            }
            await MainActor.run {
                // Clear existing audio info labels
                for label in self.audioInfoLabels {
                    self.menu.removeItem(label)
                }
                self.audioInfoLabels.removeAll()

                // Find insertion index (after all volume controls)
                guard let audioSectionIndex = self.menu.items.firstIndex(of: self.audioSectionLabel) else {
                    return
                }
                let insertIndex = audioSectionIndex + 7

                // Add new audio info labels
                for (index, line) in audioInfoLines.enumerated() {
                    let label = NSMenuItem(
                        title: line,
                        action: nil,
                        keyEquivalent: ""
                    )
                    label.isEnabled = false
                    self.menu.insertItem(label, at: insertIndex + index)
                    self.audioInfoLabels.append(label)
                }
            }
        } catch {
            await clearAudioInfoLabels()
        }
    }

    func updateVideoInfoDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await clearVideoInfoLabels()
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

                // Find insertion index (after Video section header)
                guard let videoSectionIndex = self.menu.items.firstIndex(of: self.videoSectionLabel) else {
                    return
                }
                let insertIndex = videoSectionIndex + 1

                // Add new video info labels
                for (index, line) in videoInfoLines.enumerated() {
                    let label = NSMenuItem(
                        title: line,
                        action: nil,
                        keyEquivalent: ""
                    )
                    label.isEnabled = false
                    self.menu.insertItem(label, at: insertIndex + index)
                    self.videoInfoLabels.append(label)
                }
            }
        } catch {
            await clearVideoInfoLabels()
        }
    }

    /// Async version of updateListeningModeDisplay for sequential execution
    func updateListeningModeDisplayAsync() async {
        do {
            guard let client = settings.onkyoClient else {
                await MainActor.run {
                    audioModeLabel.title = "Mode: --"
                }
                return
            }
            let listeningMode = try await retryQuery {
                try await client.getListeningMode()
            }
            await MainActor.run {
                self.audioModeLabel.title = "Mode: \(listeningMode)"
            }
        } catch {
            await MainActor.run {
                self.audioModeLabel.title = "Mode: --"
            }
        }
    }

    // MARK: - Helper Methods

    private func clearAudioInfoLabels() async {
        await MainActor.run {
            // Clear existing audio info labels
            for label in self.audioInfoLabels {
                self.menu.removeItem(label)
            }
            self.audioInfoLabels.removeAll()

            // Add placeholder after volume controls
            guard let audioSectionIndex = self.menu.items.firstIndex(of: self.audioSectionLabel) else {
                return
            }
            let label = NSMenuItem(title: "Input: --", action: nil, keyEquivalent: "")
            label.isEnabled = false
            self.menu.insertItem(label, at: audioSectionIndex + 7)
            self.audioInfoLabels.append(label)
        }
    }

    private func clearVideoInfoLabels() async {
        await MainActor.run {
            // Clear existing video info labels
            for label in self.videoInfoLabels {
                self.menu.removeItem(label)
            }
            self.videoInfoLabels.removeAll()

            // Add placeholder after Video section header
            guard let videoSectionIndex = self.menu.items.firstIndex(of: self.videoSectionLabel) else {
                return
            }
            let label = NSMenuItem(title: "Input: --", action: nil, keyEquivalent: "")
            label.isEnabled = false
            self.menu.insertItem(label, at: videoSectionIndex + 1)
            self.videoInfoLabels.append(label)
        }
    }
}
