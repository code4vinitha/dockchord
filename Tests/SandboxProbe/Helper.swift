import AppKit
@main
struct HelperMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = HelperDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.regular)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
final class HelperDelegate: NSObject, NSApplicationDelegate {
    private var window: NSWindow?
    func applicationDidFinishLaunching(_ notification: Notification) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 340, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.title = "DockChord test target"
        window.center(); window.makeKeyAndOrderFront(nil)
        self.window = window
        NSApp.activate(ignoringOtherApps: true)
        // Bound the helper lifetime if a probe fails before cleanup.
        DispatchQueue.main.asyncAfter(deadline: .now() + 45) { NSApp.terminate(nil) }
    }
}
