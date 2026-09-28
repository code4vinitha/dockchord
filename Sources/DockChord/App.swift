import SwiftUI
import AppKit

@main
struct DockChordApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene { Settings { EmptyView() } }
}
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var store: LaunchStore!
    private var window: NSWindow!
    private var statusItem: NSStatusItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        store = LaunchStore()
        window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1040, height: 780), styleMask: [.titled, .closable, .miniaturizable, .resizable], backing: .buffered, defer: false)
        window.title = "DockChord"
        window.titlebarAppearsTransparent = true
        window.backgroundColor = .windowBackgroundColor
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: SettingsView(store: store))
        window.center()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "DockChord")
        let menu = NSMenu()
        let settings = menu.addItem(withTitle: "DockChord Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        let pause = menu.addItem(withTitle: "Pause / Resume Shortcuts", action: #selector(togglePause), keyEquivalent: "")
        pause.target = self
        menu.addItem(.separator())
        let quit = menu.addItem(withTitle: "Quit DockChord", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        statusItem.menu = menu
        showSettings()
    }
    @objc func showSettings() { NSApp.activate(ignoringOtherApps: true); window.makeKeyAndOrderFront(nil) }
    @objc func togglePause() { store.paused.toggle() }
    @objc func quitApp() { NSApp.terminate(nil) }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool { showSettings(); return true }
}
