import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: LaunchStore
    private var selection: String { store.selectedPage }
    private let pages = [("Dock shortcuts", "dock.rectangle"), ("App shortcuts", "square.grid.2x2"), ("Settings", "slider.horizontal.3")]
    var body: some View {
        HStack(spacing: 20) {
            VStack(alignment: .leading, spacing: 28) {
                HStack(spacing: 10) {
                    Image(systemName: "bolt.fill").font(.title2).foregroundStyle(.white).frame(width: 42, height: 42).background(.indigo.gradient, in: RoundedRectangle(cornerRadius: 14)).shadow(color: .indigo.opacity(0.25), radius: 10, y: 4)
                    VStack(alignment: .leading, spacing: 2) { Text("DockChord").font(.headline); Text("A shortcut to everything.").font(.caption2).foregroundStyle(.secondary) }
                }
                VStack(spacing: 6) {
                    ForEach(pages, id: \.0) { page in
                        Button { store.selectedPage = page.0 } label: {
                            Label(page.0, systemImage: page.1).font(.system(size: 13, weight: .medium)).frame(maxWidth: .infinity, alignment: .leading).padding(11)
                                .background(selection == page.0 ? Color.indigo.opacity(0.17) : .clear, in: RoundedRectangle(cornerRadius: 12))
                                .foregroundStyle(selection == page.0 ? Color.indigo : Color.primary)
                        }.buttonStyle(.plain)
                    }
                }
                Spacer()
                HStack(spacing: 7) { Circle().fill(store.paused ? .orange : (store.issues.isEmpty ? .green : .orange)).frame(width: 7, height: 7); Text(store.paused ? "Shortcuts paused" : (store.issues.isEmpty ? "Ready when you are" : "Shortcuts need attention")).font(.caption).foregroundStyle(.secondary) }
                Text("Made for your keyboard.").font(.caption2).foregroundStyle(.tertiary)
            }.padding(20).frame(width: 225).frame(maxHeight: .infinity).navigationGlass()
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(selection).font(.system(size: 29, weight: .bold, design: .rounded))
                            Text(subtitle).foregroundStyle(.secondary).font(.system(size: 13))
                        }
                        Spacer()
                        if selection == "App shortcuts" { Button { store.addApp() } label: { Label("Add app", systemImage: "plus") }.glassAction(prominent: true) }
                    }
                    if store.paused { Label("Shortcuts are paused. Resume them in Settings or the menu bar.", systemImage: "pause.circle").font(.callout).foregroundStyle(.orange) }
                    if selection == "Dock shortcuts" { dockPage }
                    else if selection == "App shortcuts" { appsPage }
                    else { settingsPage }
                }.padding(12).padding(.trailing, 4)
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
        }.padding(20).frame(minWidth: 920, minHeight: 640).background(GlassBackdrop()).tint(.indigo)
            .alert("Could not launch app", isPresented: Binding(get: { store.launchError != nil }, set: { if !$0 { store.launchError = nil } })) { Button("OK") { store.launchError = nil } } message: { Text(store.launchError ?? "") }
    }
    var subtitle: String {
        switch selection {
        case "Dock shortcuts": return "Your favorite apps, one keystroke away."
        case "App shortcuts": return "Give any app a shortcut that feels natural."
        default: return "Small preferences. A faster everyday workflow."
        }
    }
    var dockPage: some View {
        VStack(alignment: .leading, spacing: 20) {
            if !AppCapabilities.automaticDockAccess {
                Label("Automatic Dock shortcuts are unavailable in this build. Add individual applications in App shortcuts.", systemImage: "info.circle")
                    .font(.callout).foregroundStyle(.secondary)
            }
            card {
                Toggle("Enable numbered Dock shortcuts", isOn: $store.preferences.dockEnabled).font(.headline).toggleStyle(.switch).disabled(!AppCapabilities.automaticDockAccess)
                Divider().padding(.vertical, 8)
                Text("HOLD THESE MODIFIERS + A NUMBER").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary)
                ModifierPicker(value: $store.preferences.modifiers)
                Text("1–9 open the first nine pinned apps. 0 opens the tenth.").font(.caption).foregroundStyle(.secondary)
            }
            HStack { Text("PINNED IN YOUR DOCK").font(.system(size: 10, weight: .semibold)).tracking(1).foregroundStyle(.secondary); Spacer(); Button { store.refreshDock() } label: { Label("Refresh", systemImage: "arrow.clockwise") }.glassAction() }
            if !AppCapabilities.automaticDockAccess {
                empty("Make shortcuts your own", detail: "Open App shortcuts to assign a key combination to each application you choose.", icon: "keyboard")
            } else if store.dockApps.isEmpty {
                empty("Your Dock is ready for some favorites", detail: "Pin applications to the Dock, then refresh to see their shortcuts.", icon: "dock.rectangle")
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(store.dockApps.enumerated()), id: \.element.id) { index, target in
                        HStack(spacing: 13) {
                            Text(String(index + 1)).font(.caption.monospacedDigit()).foregroundStyle(.tertiary).frame(width: 18)
                            appIdentity(target)
                            Spacer()
                            if store.preferences.dockEnabled { keycap(store.preferences.modifiers.symbols + LaunchKey.numbers[index].label) }
                            else { Text("Off").foregroundStyle(.secondary).font(.caption) }
                            Button { store.launch(target) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(.borderless).help("Open \(target.name)")
                        }.padding(13)
                        if let issue = store.issues["dock-\(index)"] { issueLabel(issue).padding(.horizontal, 16).padding(.bottom, 10) }
                        if index < store.dockApps.count - 1 { Divider().padding(.leading, 54) }
                    }
                }.frostedSurface()
            }
            Label("Follows your Dock order automatically. Finder is optional in Settings.", systemImage: "arrow.triangle.2.circlepath").font(.caption).foregroundStyle(.secondary)
        }
    }
    var appsPage: some View {
        VStack(spacing: 14) {
            if store.preferences.shortcuts.isEmpty {
                empty("Your apps. Your shortcuts.", detail: "Add Visual Studio Code and choose ⌥ V, or create a shortcut for any application on your Mac.", icon: "keyboard")
                Button("Choose an application…") { store.addApp() }.glassAction()
            }
            ForEach($store.preferences.shortcuts) { $shortcut in
                card {
                    HStack {
                        appIdentity(shortcut.target)
                        Spacer()
                        Toggle("Enabled", isOn: $shortcut.enabled).labelsHidden().toggleStyle(.switch).accessibilityLabel("Enable shortcut for \(shortcut.target.name)")
                        Button(role: .destructive) { store.preferences.shortcuts.removeAll { $0.id == shortcut.id } } label: { Image(systemName: "trash") }.buttonStyle(.borderless).help("Remove shortcut")
                    }
                    HStack {
                        ModifierPicker(value: $shortcut.modifiers)
                        Text("+").foregroundStyle(.tertiary)
                        Picker("Key", selection: $shortcut.key) { ForEach(LaunchKey.all) { key in Text(key.label).tag(key.code) } }.labelsHidden().frame(width: 65)
                    }.padding(.top, 7)
                    if let issue = store.issues[shortcut.id.uuidString] { issueLabel(issue) }
                }
            }
            if !store.preferences.shortcuts.isEmpty { Text("Shortcuts are saved automatically. Letter labels use US keyboard positions.").font(.caption).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading) }
        }
    }
    var settingsPage: some View {
        VStack(alignment: .leading, spacing: 18) {
            card {
                settingToggle("Pause all shortcuts", detail: "Temporarily release all registered keyboard shortcuts.", value: $store.paused)
                Divider().padding(.vertical, 8)
                settingToggle("Count Finder as the first Dock app", detail: "Finder takes number 1; pinned applications follow it.", value: $store.preferences.includeFinder)
                Divider().padding(.vertical, 8)
                settingToggle("Press again to hide", detail: "Hide the app when its shortcut is pressed while it is active.", value: $store.preferences.peek)
            }
            card {
                Label("Always within reach", systemImage: "menubar.rectangle").font(.headline)
                Text("Closing this window keeps DockChord running in the menu bar. Click the bolt icon to reopen settings, pause shortcuts, or quit.").font(.callout).foregroundStyle(.secondary)
                Text("To start automatically, add DockChord in System Settings → General → Login Items.").font(.caption).foregroundStyle(.secondary)
            }
            Text("Some shortcuts are reserved by macOS or other apps. An unavailable shortcut is flagged in its row. Duplicate shortcuts are disabled until you resolve the conflict.").font(.caption).foregroundStyle(.secondary)
        }
    }
    func settingToggle(_ title: String, detail: String, value: Binding<Bool>) -> some View {
        Toggle(isOn: value) { VStack(alignment: .leading, spacing: 5) { Text(title).font(.system(size: 13, weight: .medium)); Text(detail).font(.caption).foregroundStyle(.secondary) } }.toggleStyle(.switch)
    }
    func card<Content: View>(@ViewBuilder content: () -> Content) -> some View { VStack(alignment: .leading, spacing: 12, content: content).padding(20).frame(maxWidth: .infinity, alignment: .leading).frostedSurface() }
    func appIdentity(_ app: AppTarget) -> some View { HStack(spacing: 12) { Image(nsImage: app.icon).resizable().frame(width: 34, height: 34); Text(app.name).font(.system(size: 13, weight: .medium)) }.help(app.url.path) }
    func keycap(_ text: String) -> some View { Text(text).font(.system(size: 13, weight: .medium, design: .monospaced)).padding(.horizontal, 11).padding(.vertical, 6).frostedSurface(radius: 8) }
    func issueLabel(_ text: String) -> some View { Label(text, systemImage: "exclamationmark.triangle.fill").font(.caption).foregroundStyle(.orange) }
    func empty(_ title: String, detail: String, icon: String) -> some View { VStack(spacing: 13) { Image(systemName: icon).font(.system(size: 40, weight: .light)).foregroundStyle(.indigo); Text(title).font(.headline); Text(detail).font(.callout).foregroundStyle(.secondary).multilineTextAlignment(.center).frame(maxWidth: 350) }.frame(maxWidth: .infinity).padding(.vertical, 55) }
}
struct ModifierPicker: View {
    @Binding var value: Modifiers
    var body: some View {
        GlassControlGroup {
            HStack(spacing: 8) {
                ForEach(Modifiers.choices, id: \.0) { label, modifier in
                    Button {
                        if value.contains(modifier) { value.remove(modifier) } else { value.insert(modifier) }
                    } label: {
                        Text(label).font(.system(size: 11, weight: .semibold))
                            .padding(.horizontal, 3).padding(.vertical, 4)
                    }
                    .glassAction(prominent: value.contains(modifier))
                    .accessibilityAddTraits(value.contains(modifier) ? .isSelected : [])
                    .accessibilityValue(value.contains(modifier) ? "Selected" : "Not selected")
                }
            }
        }
    }
}
