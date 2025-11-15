import Cocoa

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

// MARK: - NSMenuItem Extensions

extension NSMenuItem {
    static func sectionHeader(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }
}
