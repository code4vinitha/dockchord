import AppKit
import SwiftUI

// Render the actual settings views with sample data, without touching saved
// preferences, the user's Dock, or global keyboard shortcut registrations.
@main
struct Screenshots {
    @MainActor static func main() throws {
        guard CGPreflightScreenCaptureAccess() else {
            fputs("Screen Recording permission is not yet available to the invoking app.\n", stderr)
            exit(EXIT_FAILURE)
        }
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        app.finishLaunching()
        let store = LaunchStore(previewMode: true)
        store.dock = ["/System/Applications/Calendar.app", "/System/Applications/Notes.app", "/System/Applications/Mail.app", "/System/Applications/Music.app", "/System/Applications/Photos.app", "/System/Applications/Utilities/Terminal.app"].map { AppTarget(url: URL(fileURLWithPath: $0)) }
        store.preferences.shortcuts = [
            CustomShortcut(path: "/Applications/Visual Studio Code.app", key: 9),
            CustomShortcut(path: "/System/Applications/Notes.app", key: 45),
            CustomShortcut(path: "/System/Applications/Utilities/Terminal.app", key: 17, modifiers: [.control, .option])
        ]
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 820), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        window.title = "DockChord"
        window.appearance = NSAppearance(named: .aqua)
        let dark = CommandLine.arguments.contains("--dark")
        let opaque = CommandLine.arguments.contains("--opaque")
        window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
        let view = NSHostingView(rootView: SettingsView(store: store)
            .environment(\.colorScheme, dark ? .dark : .light)
            .environment(\.opaqueSurfacePreview, opaque))
        window.contentView = view
        window.center()
        window.makeKeyAndOrderFront(nil)
        app.activate(ignoringOtherApps: true)
        let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        for (page, name) in [("Dock shortcuts", "dock-shortcuts"), ("App shortcuts", "app-shortcuts"), ("Settings", "settings")] {
            store.selectedPage = page
            RunLoop.main.run(until: Date().addingTimeInterval(1))
            view.layoutSubtreeIfNeeded()
            view.display()
            // Glass is composited by the window server and is not included in
            // NSView bitmap caching. Capture the actual window, including glass.
            let capture = Process()
            capture.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            capture.arguments = ["-x", "-o", "-l", String(window.windowNumber), output.appendingPathComponent(name + ".png").path]
            try capture.run()
            capture.waitUntilExit()
            guard capture.terminationStatus == 0 else {
                fputs("Window capture failed. Allow Screen Recording for the invoking app and retry.\n", stderr)
                exit(EXIT_FAILURE)
            }
            print("Captured \(page)")
        }
        window.orderOut(nil)
    }
}
