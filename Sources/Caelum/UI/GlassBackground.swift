import SwiftUI

/// SwiftUI-side glass: a translucent obsidian gradient that lets the panel's
/// behind-window vibrancy show through, with a soft accent aurora glow that
/// re-tints to the current image.
struct GlassBackground: View {
    var accent: Color

    var body: some View {
        ZStack {
            // Real frosted vibrancy sits behind (NSVisualEffectView); keep the
            // obsidian tint translucent so the blur reads as glass.
            Theme.Gradients.panel.opacity(0.6)
            RadialGradient(colors: [accent.opacity(0.24), .clear],
                           center: .topTrailing, startRadius: 0, endRadius: 300)
            RadialGradient(colors: [Theme.Palette.auroraCyan.opacity(0.10), .clear],
                           center: .bottomLeading, startRadius: 0, endRadius: 240)
        }
        .ignoresSafeArea()
    }
}

// MARK: - Snapshot environment (static layout for offscreen renders)

private struct IsSnapshotKey: EnvironmentKey { static let defaultValue = false }
extension EnvironmentValues {
    var isSnapshot: Bool {
        get { self[IsSnapshotKey.self] }
        set { self[IsSnapshotKey.self] = newValue }
    }
}

// MARK: - Reusable surface & label modifiers

extension View {
    /// Raised glass card surface with a luminous hairline.
    func glassCard(cornerRadius: CGFloat = Theme.Metrics.radiusCard, fill: Double = 0.5) -> some View {
        background(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Theme.Palette.obsidian2.opacity(fill))
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
        )
    }

    /// All-caps micro label with wide tracking.
    func microLabel(_ color: Color = Theme.Palette.textSecondary) -> some View {
        font(Theme.Fonts.micro())
            .tracking(Theme.Metrics.microTracking)
            .textCase(.uppercase)
            .foregroundStyle(color)
    }
}

// MARK: - Button styles

/// Circular glass icon button used throughout the control deck and footer.
struct GlassIconButtonStyle: ButtonStyle {
    var size: CGFloat = 42
    var tint: Color = Theme.Palette.textPrimary
    var active: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: size * 0.38, weight: .semibold))
            .foregroundStyle(active ? Color.black : tint)
            .frame(width: size, height: size)
            .background(
                Circle().fill(active
                    ? AnyShapeStyle(Theme.Gradients.aurora)
                    : AnyShapeStyle(Theme.Palette.obsidian2.opacity(0.66)))
            )
            .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            .scaleEffect(configuration.isPressed ? 0.9 : 1)
            .shadow(color: active ? tint.opacity(0.5) : .clear, radius: 10, y: 2)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .animation(Theme.Motion.snappy, value: active)
    }
}

/// Primary aurora pill (the "Set as Wallpaper" action).
struct AuroraPillButtonStyle: ButtonStyle {
    var filled: Bool = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(Theme.Fonts.title(14))
            .foregroundStyle(isEnabled
                ? (filled ? Color.black : Theme.Palette.textPrimary)
                : Theme.Palette.textTertiary)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusButton, style: .continuous)
                    .fill(isEnabled && filled
                        ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                        : AnyShapeStyle(Theme.Palette.obsidian2.opacity(0.7)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusButton, style: .continuous)
                    .strokeBorder(Color.white.opacity(isEnabled && filled ? 0.18 : 0.10), lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(isEnabled ? 1 : 0.55)
            .shadow(color: isEnabled && filled ? Theme.Palette.auroraViolet.opacity(0.45) : .clear,
                    radius: 14, y: 4)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
            .animation(Theme.Motion.snappy, value: isEnabled)
    }
}
