import AppKit
import Carbon

// A diagnostic executable, never included in the shipping app. It uses the
// production DockReader and HotKeyRegistry and writes only to its own container.
@main
struct ProbeMain {
    static func main() {
        let app = NSApplication.shared
        let delegate = ProbeDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
        withExtendedLifetime(delegate) {}
    }
}
final class ProbeDelegate: NSObject, NSApplicationDelegate {
    private var registry: HotKeyRegistry?
    private var report: [String: Any] = [:]
    private var helper: NSRunningApplication?
    private var window: NSWindow?
    private var finished = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        let args = CommandLine.arguments
        func argument(_ flag: String) -> String? {
            guard let i = args.firstIndex(of: flag), i + 1 < args.count else { return nil }
            return args[i + 1]
        }
        report["runID"] = argument("--run-id")
        report["bundleID"] = Bundle.main.bundleIdentifier
        report["sandboxContainerHome"] = NSHomeDirectory().contains("/Library/Containers/")
        report["osVersion"] = ProcessInfo.processInfo.operatingSystemVersionString
        if let path = argument("--boundary-file") {
            report["outsideContainerReadDenied"] = (try? Data(contentsOf: URL(fileURLWithPath: path))) == nil
        }
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        report["dockDomainReadable"] = CFPreferencesCopyAppValue("persistent-apps" as CFString, "com.apple.dock" as CFString) != nil
        report["dockPinnedAppCount"] = DockReader.read().count
        let defaults = UserDefaults.standard
        defaults.set("probe-ok", forKey: "sandboxProbe")
        report["ownPreferencesRoundTrip"] = defaults.string(forKey: "sandboxProbe") == "probe-ok"
        defaults.removeObject(forKey: "sandboxProbe")
        registry = HotKeyRegistry()
        let target = AppTarget(url: URL(fileURLWithPath: argument("--helper") ?? "/nonexistent.app"))
        let spec = BindingSpec(id: "probe", target: target, key: 9, modifiers: [.control, .option, .shift, .command])
        report["hotkeyRegistrationStatus"] = registry?.register(spec) { [weak self] in
            self?.report["physicalHotkeyReceived"] = true
            self?.finish()
        }
        report["physicalHotkeyReceived"] = false
        report["physicalHotkeyTest"] = args.contains("--interactive") ? "waiting" : "not tested"
        if args.contains("--interactive") {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 530, height: 140), styleMask: [.titled], backing: .buffered, defer: false)
            window.title = "DockChord Sandbox Probe"
            let label = NSTextField(wrappingLabelWithString: "Press Control + Option + Shift + Command + V to test a real global shortcut. This probe exits after 30 seconds.")
            label.frame = NSRect(x: 24, y: 35, width: 480, height: 70)
            window.contentView?.addSubview(label)
            window.center(); window.makeKeyAndOrderFront(nil)
            self.window = window
        }
        let config = NSWorkspace.OpenConfiguration()
        config.activates = true
        NSWorkspace.shared.openApplication(at: target.url, configuration: config) { [weak self] running, error in
            DispatchQueue.main.async {
                guard let self else { return }
                self.helper = running
                self.report["launchSucceeded"] = running != nil && error == nil
                if let error { self.report["launchError"] = error.localizedDescription }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    if let running {
                        self.report["helperWasActive"] = running.isActive
                        self.report["helperWasHiddenBefore"] = running.isHidden
                        self.report["hideAccepted"] = running.hide()
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.report["helperIsHidden"] = running?.isHidden ?? false
                        if !args.contains("--interactive") { self.finish() }
                    }
                }
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + (args.contains("--interactive") ? 30 : 10)) { self.finish() }
    }
    private func finish() {
        guard !finished else { return }; finished = true
        if report["physicalHotkeyTest"] as? String == "waiting" {
            report["physicalHotkeyTest"] = (report["physicalHotkeyReceived"] as? Bool == true) ? "passed" : "timed out"
        }
        helper?.terminate()
        registry?.clear()
        do {
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("DockChordProbe")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
            try data.write(to: directory.appendingPathComponent("report.json"))
        } catch { fputs("Probe report failed: \(error)\n", stderr) }
        NSApp.terminate(nil)
    }
}
