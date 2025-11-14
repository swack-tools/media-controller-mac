import Cocoa

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("MediaControl: App started")

        // Initialize status bar controller
        statusBarController = StatusBarController()

        NSLog("MediaControl: Initialization complete")
    }

    func applicationWillTerminate(_ notification: Notification) {
        statusBarController?.cleanup()
    }
}
