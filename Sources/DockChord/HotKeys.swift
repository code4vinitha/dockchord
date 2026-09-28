import AppKit
import Carbon

final class HotKeyRegistry {
    private var handler: EventHandlerRef?
    private var refs: [EventHotKeyRef] = []
    private var actions: [UInt32: () -> Void] = [:]
    init() {
        var event = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, context in
            guard let event, let context else { return OSStatus(eventNotHandledErr) }
            var hotKey = EventHotKeyID()
            let status = GetEventParameter(event, EventParamName(kEventParamDirectObject), EventParamType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKey)
            guard status == noErr else { return status }
            let registry = Unmanaged<HotKeyRegistry>.fromOpaque(context).takeUnretainedValue()
            registry.actions[hotKey.id]?()
            return noErr
        }, 1, &event, Unmanaged.passUnretained(self).toOpaque(), &handler)
    }
    func clear() {
        refs.forEach { UnregisterEventHotKey($0) }
        refs.removeAll()
        actions.removeAll()
    }
    func register(_ spec: BindingSpec, action: @escaping () -> Void) -> OSStatus {
        guard handler != nil else { return OSStatus(eventNotHandledErr) }
        let id = UInt32(actions.count + 1)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(spec.key, spec.modifiers.rawValue, EventHotKeyID(signature: 0x44434844, id: id), GetApplicationEventTarget(), 0, &ref)
        if status == noErr, let ref { refs.append(ref); actions[id] = action }
        return status
    }
    deinit { clear(); if let handler { RemoveEventHandler(handler) } }
}

final class LaunchStore: ObservableObject {
    @Published var selectedPage = "Dock shortcuts"
    @Published var preferences: Preferences { didSet { saveAndRegister() } }
    @Published var dock: [AppTarget] = []
    @Published var issues: [String: String] = [:]
    @Published var launchError: String?
    @Published var paused = false { didSet { rebuild() } }
    private let registry = HotKeyRegistry()
    private var timer: Timer?
    private let defaults: UserDefaults
    private let previewMode: Bool
    init(defaults: UserDefaults = .standard, previewMode: Bool = false) {
        self.previewMode = previewMode
        self.defaults = defaults
        if !previewMode, let data = defaults.data(forKey: "preferences"), let decoded = try? JSONDecoder().decode(Preferences.self, from: data) { preferences = decoded }
        else { preferences = Preferences() }
        guard !previewMode else { return }
        refreshDock()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in self?.refreshDock() }
    }
    var dockApps: [AppTarget] {
        let finder = AppTarget(url: URL(fileURLWithPath: "/System/Library/CoreServices/Finder.app"))
        return Array((preferences.includeFinder ? [finder] + dock.filter { $0.url != finder.url } : dock).prefix(10))
    }
    var specs: [BindingSpec] {
        let numbered = preferences.dockEnabled ? dockApps.enumerated().map { BindingSpec(id: "dock-\($0.offset)", target: $0.element, key: LaunchKey.numbers[$0.offset].code, modifiers: preferences.modifiers) } : []
        return numbered + preferences.shortcuts.filter(\.enabled).map { BindingSpec(id: $0.id.uuidString, target: $0.target, key: $0.key, modifiers: $0.modifiers) }
    }
    func refreshDock() {
        guard !previewMode else { return }
        let current = DockReader.read()
        if current != dock { dock = current }
        // Rebuild only on changes; initial registration also handles saved manual shortcuts.
        let signature = specs.map { $0.id + $0.chord + $0.target.id }.joined(separator: "|")
        if signature != lastSignature { rebuild() }
    }
    private var lastSignature = "uninitialized"
    private func saveAndRegister() {
        guard !previewMode else { return }
        if let data = try? JSONEncoder().encode(preferences) { defaults.set(data, forKey: "preferences") }
        rebuild()
    }
    func rebuild() {
        guard !previewMode else { return }
        registry.clear()
        issues = [:]
        let bindings = specs
        lastSignature = bindings.map { $0.id + $0.chord + $0.target.id }.joined(separator: "|")
        guard !paused else { return }
        let groups = Dictionary(grouping: bindings, by: \.chord)
        for spec in bindings {
            if spec.modifiers.isEmpty { issues[spec.id] = "Choose at least one modifier."; continue }
            if (groups[spec.chord]?.count ?? 0) > 1 { issues[spec.id] = "Duplicate shortcut. Choose a different key or modifier."; continue }
            if !FileManager.default.fileExists(atPath: spec.target.url.path) { issues[spec.id] = "App no longer exists. Remove and add it again."; continue }
            let status = registry.register(spec) { [weak self] in self?.launch(spec.target) }
            if status != noErr { issues[spec.id] = "Shortcut unavailable (\(status)). Try another combination." }
        }
    }
    func launch(_ target: AppTarget) {
        if preferences.peek, let bundleID = Bundle(url: target.url)?.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first, running.isActive {
            running.hide(); return
        }
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.openApplication(at: target.url, configuration: configuration) { [weak self] _, error in
            if let error { DispatchQueue.main.async { self?.launchError = error.localizedDescription } }
        }
    }
    func addApp() {
        let panel = NSOpenPanel()
        panel.title = "Choose an application"
        panel.directoryURL = URL(fileURLWithPath: "/Applications")
        panel.allowedContentTypes = [.applicationBundle]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        if panel.runModal() == .OK {
            for url in panel.urls {
                let used = Set(preferences.shortcuts.filter { $0.modifiers == .option }.map(\.key))
                let firstLetter = AppTarget(url: url).name.prefix(1).uppercased()
                let preferred = LaunchKey.all.first { $0.label == firstLetter && !used.contains($0.code) }
                let key = preferred ?? LaunchKey.all.first { !used.contains($0.code) } ?? LaunchKey.all[0]
                preferences.shortcuts.append(CustomShortcut(path: url.path, key: key.code))
            }
        }
    }
}
