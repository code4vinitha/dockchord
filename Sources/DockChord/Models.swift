import AppKit
import Carbon

struct Modifiers: OptionSet, Codable, Hashable {
    let rawValue: UInt32
    static let command = Modifiers(rawValue: UInt32(cmdKey))
    static let option = Modifiers(rawValue: UInt32(optionKey))
    static let control = Modifiers(rawValue: UInt32(controlKey))
    static let shift = Modifiers(rawValue: UInt32(shiftKey))
    static let choices: [(String, Modifiers)] = [("⌃ Control", .control), ("⌥ Option", .option), ("⇧ Shift", .shift), ("⌘ Command", .command)]
    var symbols: String { Self.choices.filter { contains($0.1) }.map { String($0.0.prefix(1)) }.joined() }
}
struct LaunchKey: Identifiable {
    let label: String
    let code: UInt32
    var id: UInt32 { code }
    static let all: [LaunchKey] = [
        ("A",0),("B",11),("C",8),("D",2),("E",14),("F",3),("G",5),("H",4),("I",34),("J",38),("K",40),("L",37),("M",46),("N",45),("O",31),("P",35),("Q",12),("R",15),("S",1),("T",17),("U",32),("V",9),("W",13),("X",7),("Y",16),("Z",6),
        ("1",18),("2",19),("3",20),("4",21),("5",23),("6",22),("7",26),("8",28),("9",25),("0",29)
    ].map { LaunchKey(label: $0.0, code: UInt32($0.1)) }
    static let numbers = Array(all.suffix(10))
    static func label(_ code: UInt32) -> String { all.first { $0.code == code }?.label ?? "?" }
}
struct AppTarget: Identifiable, Equatable {
    let url: URL
    var id: String { url.path }
    var name: String { FileManager.default.displayName(atPath: url.path).replacingOccurrences(of: ".app", with: "") }
    var icon: NSImage { NSWorkspace.shared.icon(forFile: url.path) }
}
struct CustomShortcut: Identifiable, Codable {
    var id = UUID()
    var path: String
    var key: UInt32 = 9
    var modifiers: Modifiers = .option
    var enabled = true
    var target: AppTarget { AppTarget(url: URL(fileURLWithPath: path)) }
}
struct Preferences: Codable {
    var dockEnabled = true
    var modifiers: Modifiers = .option
    var includeFinder = false
    var peek = false
    var shortcuts: [CustomShortcut] = []
}
struct BindingSpec {
    let id: String
    let target: AppTarget
    let key: UInt32
    let modifiers: Modifiers
    var chord: String { "\(modifiers.rawValue):\(key)" }
    var label: String { modifiers.symbols + LaunchKey.label(key) }
}
enum AppCapabilities {
    // Distribution builds explicitly opt out of reading another process's
    // preference domain. Direct builds retain their existing behavior.
    static var automaticDockAccess: Bool {
        allowsDockPreferences(Bundle.main.object(forInfoDictionaryKey: "DockChordAllowsDockPreferences"))
    }
    static func allowsDockPreferences(_ value: Any?) -> Bool {
        guard let value else { return true }
        if let flag = value as? Bool { return flag }
        if let flag = value as? String { return ["yes", "true", "1"].contains(flag.lowercased()) }
        return false
    }
}
enum DockReader {
    static func targets(from items: [[String: Any]]) -> [AppTarget] {
        items.compactMap { item in
            guard item["tile-type"] as? String == "file-tile",
                  let data = item["tile-data"] as? [String: Any],
                  let file = data["file-data"] as? [String: Any],
                  let value = file["_CFURLString"] as? String,
                  let url = URL(string: value), url.isFileURL,
                  url.pathExtension.lowercased() == "app" else { return nil }
            return AppTarget(url: url)
        }
    }
    static func read() -> [AppTarget] {
        guard AppCapabilities.automaticDockAccess else { return [] }
        CFPreferencesAppSynchronize("com.apple.dock" as CFString)
        let items = CFPreferencesCopyAppValue("persistent-apps" as CFString, "com.apple.dock" as CFString) as? [[String: Any]] ?? []
        return targets(from: items)
    }
}
