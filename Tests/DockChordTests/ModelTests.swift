import Foundation

func expectEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs == rhs, "Expected \(lhs) == \(rhs)") }
func expectNotEqual<T: Equatable>(_ lhs: T, _ rhs: T) { precondition(lhs != rhs) }
func expectTrue(_ value: Bool) { precondition(value) }
func expectFalse(_ value: Bool) { precondition(!value) }

@main
struct ModelTests {
    static func main() throws {
        let tests = ModelTests()
        tests.testDockOrderAndFiltering()
        try tests.testPreferencesRoundTrip()
        tests.testNumberOrderAndChordIdentity()
        tests.testSandboxDockOptOut()
        print("Passed 4 model checks: sandbox Dock opt-out, Dock order/filtering, preferences round trip, shortcut identity.")
    }
    func testSandboxDockOptOut() {
        expectFalse(AppCapabilities.allowsDockPreferences(false))
        expectFalse(AppCapabilities.allowsDockPreferences("NO"))
        expectFalse(AppCapabilities.allowsDockPreferences("false"))
        expectFalse(AppCapabilities.allowsDockPreferences("$(UNEXPANDED)"))
        expectTrue(AppCapabilities.allowsDockPreferences(true))
        expectTrue(AppCapabilities.allowsDockPreferences("YES"))
        expectTrue(AppCapabilities.allowsDockPreferences(nil))
    }
    func testDockOrderAndFiltering() {
        func tile(_ path: String) -> [String: Any] { ["tile-type": "file-tile", "tile-data": ["file-data": ["_CFURLString": path]]] }
        let apps = DockReader.targets(from: [tile("file:///Applications/Safari.app/"), ["tile-type": "spacer-tile"], tile("file:///Users/example/Downloads/"), tile("file:///Applications/Visual%20Studio%20Code.app/"), tile("https://example.com/Remote.app")])
        expectEqual(apps.map(\.url.path), ["/Applications/Safari.app", "/Applications/Visual Studio Code.app"])
    }
    func testPreferencesRoundTrip() throws {
        var prefs = Preferences()
        prefs.modifiers = [.control, .option, .shift, .command]
        prefs.includeFinder = true
        prefs.peek = true
        prefs.shortcuts = [CustomShortcut(path: "/Applications/Visual Studio Code.app", key: 9, modifiers: [.option, .shift], enabled: false)]
        let decoded = try JSONDecoder().decode(Preferences.self, from: JSONEncoder().encode(prefs))
        expectEqual(decoded.modifiers, prefs.modifiers)
        expectEqual(decoded.shortcuts[0].id, prefs.shortcuts[0].id)
        expectEqual(decoded.shortcuts[0].modifiers, [.option, .shift])
        expectFalse(decoded.shortcuts[0].enabled)
        expectTrue(decoded.includeFinder)
        expectTrue(decoded.peek)
    }
    func testNumberOrderAndChordIdentity() {
        expectEqual(LaunchKey.numbers.map(\.label), ["1","2","3","4","5","6","7","8","9","0"])
        let target = AppTarget(url: URL(fileURLWithPath: "/Applications/Safari.app"))
        let a = BindingSpec(id: "dock-0", target: target, key: 18, modifiers: .option)
        let b = BindingSpec(id: "custom", target: target, key: 18, modifiers: .option)
        let c = BindingSpec(id: "other", target: target, key: 18, modifiers: [.option, .shift])
        expectEqual(a.chord, b.chord)
        expectNotEqual(a.chord, c.chord)
        expectEqual(a.label, "⌥1")
    }
}
