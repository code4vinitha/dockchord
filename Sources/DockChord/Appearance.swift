import SwiftUI

// Preview override lets the screenshot harness verify opaque styling without
// changing the user's system accessibility preferences.
private struct OpaqueSurfacePreviewKey: EnvironmentKey {
    static let defaultValue = false
}
extension EnvironmentValues {
    var opaqueSurfacePreview: Bool {
        get { self[OpaqueSurfacePreviewKey.self] }
        set { self[OpaqueSurfacePreviewKey.self] = newValue }
    }
}

/// Native glass is confined to navigation and controls; content cards use
/// material so text stays legible and glass layers do not stack on each other.
struct GlassBackdrop: View {
    @Environment(\.colorScheme) private var scheme
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.opaqueSurfacePreview) private var opaquePreview
    private var reduceTransparency: Bool { systemReduceTransparency || opaquePreview }

    var body: some View {
        ZStack {
            Color(nsColor: .windowBackgroundColor)
            if !reduceTransparency {
                LinearGradient(colors: [Color.indigo.opacity(scheme == .dark ? 0.22 : 0.12), Color.cyan.opacity(0.07), Color.purple.opacity(0.10)], startPoint: .topLeading, endPoint: .bottomTrailing)
                RadialGradient(colors: [Color.indigo.opacity(0.19), .clear], center: .topLeading, startRadius: 10, endRadius: 650)
                RadialGradient(colors: [Color.cyan.opacity(0.13), .clear], center: .bottomTrailing, startRadius: 10, endRadius: 500)
            }
        }.ignoresSafeArea().allowsHitTesting(false)
    }
}

private struct Surface: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.opaqueSurfacePreview) private var opaquePreview
    private var reduceTransparency: Bool { systemReduceTransparency || opaquePreview }
    @Environment(\.colorScheme) private var scheme
    let radius: CGFloat
    let glass: Bool

    @ViewBuilder func body(content: Content) -> some View {
        if reduceTransparency {
            content.background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(Color.primary.opacity(0.16)))
        } else if #available(macOS 26.0, *), glass {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: radius))
        } else {
            content.background(.regularMaterial, in: RoundedRectangle(cornerRadius: radius))
                .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(
                    LinearGradient(colors: [.white.opacity(scheme == .dark ? 0.22 : 0.85), .white.opacity(0.08), .white.opacity(0.35)], startPoint: .topLeading, endPoint: .bottomTrailing)))
                .shadow(color: .black.opacity(scheme == .dark ? 0.12 : 0.04), radius: 12, y: 5)
        }
    }
}

private struct GlassAction: ViewModifier {
    @Environment(\.accessibilityReduceTransparency) private var systemReduceTransparency
    @Environment(\.opaqueSurfacePreview) private var opaquePreview
    private var reduceTransparency: Bool { systemReduceTransparency || opaquePreview }
    var prominent: Bool
    @ViewBuilder func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !reduceTransparency {
            if prominent { content.buttonStyle(.glassProminent).tint(.indigo) }
            else { content.buttonStyle(.glass) }
        } else {
            if prominent { content.buttonStyle(.borderedProminent).tint(.indigo) }
            else { content.buttonStyle(.bordered) }
        }
    }
}

struct GlassControlGroup<Content: View>: View {
    @ViewBuilder var content: () -> Content
    @ViewBuilder var body: some View {
        if #available(macOS 26.0, *) { GlassEffectContainer(spacing: 6) { content() } }
        else { content() }
    }
}

extension View {
    func frostedSurface(radius: CGFloat = 20) -> some View { modifier(Surface(radius: radius, glass: false)) }
    func navigationGlass() -> some View { modifier(Surface(radius: 24, glass: true)) }
    func glassAction(prominent: Bool = false) -> some View { modifier(GlassAction(prominent: prominent)) }
}
