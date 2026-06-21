import SwiftUI

/// Scrollable 3-column grid of all image sources. Fills the space between the
/// control deck and the footer. The active source glows with the aurora
/// gradient; each cell shows a typical-resolution badge.
struct SourceStrip: View {
    @EnvironmentObject var app: AppState
    @Environment(\.isSnapshot) private var isSnapshot

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    private var grid: some View {
        LazyVGrid(columns: columns, spacing: 8) {
            ForEach(app.sources, id: \.id) { source in
                SourceCell(
                    source: source,
                    active: source.id == app.activeSourceID,
                    hasUpdate: app.sourcesWithUpdates.contains(source.id),
                    accent: app.accent
                ) {
                    app.selectSource(source.id)
                }
            }
        }
        .padding(.horizontal, Theme.Metrics.space4)
        .padding(.bottom, Theme.Metrics.space3)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Section divider sits *above* the heading, so it never collides with
            // the first row of source tiles the way a grid-top overlay did.
            Rectangle()
                .fill(Theme.Palette.hairline.opacity(0.6))
                .frame(height: 1)
                .padding(.horizontal, Theme.Metrics.space4)
                .padding(.bottom, 2)

            Text("Sources")
                .microLabel()
                .padding(.horizontal, Theme.Metrics.space5)

            Group {
                if isSnapshot {
                    // ScrollView renders empty offscreen — show the grid directly.
                    grid
                } else {
                    ScrollView(.vertical, showsIndicators: false) { grid }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, Theme.Metrics.space1)
    }
}

private struct SourceCell: View {
    let source: ImageSource
    let active: Bool
    var hasUpdate: Bool = false
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                ZStack {
                    Circle()
                        .fill(active
                            ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                            : AnyShapeStyle(Theme.Palette.obsidian3.opacity(0.85)))
                        .frame(width: 32, height: 32)
                    Image(systemName: source.symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(active ? Color.black : Theme.Palette.textSecondary)

                    // "New images" indicator — a softly pulsing cyan ring that
                    // encircles the icon until the user opens this source.
                    if hasUpdate && !active {
                        NewContentRing()
                    }
                }
                .shadow(color: active ? accent.opacity(0.55) : .clear, radius: 7, y: 2)

                Text(source.name)
                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                    .foregroundStyle(active ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                resBadge(source.typicalResolution)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 9)
            .padding(.horizontal, 3)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusChip, style: .continuous)
                    .fill(active
                        ? AnyShapeStyle(Theme.Palette.obsidian2.opacity(0.95))
                        : AnyShapeStyle(Theme.Palette.obsidian1.opacity(0.45)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusChip, style: .continuous)
                    .strokeBorder(
                        active ? AnyShapeStyle(Theme.Gradients.auroraHorizontal.opacity(0.55))
                               : AnyShapeStyle(Theme.Palette.hairline),
                        lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .animation(Theme.Motion.snappy, value: active)
    }

    @ViewBuilder
    private func resBadge(_ hint: ResolutionHint) -> some View {
        let c = Color(hex: hint.accentHex)
        Text(hint.rawValue)
            .font(.system(size: 8, weight: .bold, design: .monospaced))
            .tracking(0.5)
            .foregroundStyle(c)
            .padding(.horizontal, 5).padding(.vertical, 1.5)
            .background(Capsule().fill(c.opacity(0.12)))
            .overlay(Capsule().strokeBorder(c.opacity(0.25), lineWidth: 0.5))
    }
}

/// A gently pulsing cyan ring drawn around a source icon to signal that the
/// library has new images the user hasn't opened yet.
private struct NewContentRing: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let pulse = 0.5 + 0.5 * sin(t * 2.2)          // 0…1
            ZStack {
                // Encircling ring, slightly larger than the 32pt icon.
                Circle()
                    .strokeBorder(Theme.Palette.auroraCyan, lineWidth: 1.6)
                    .frame(width: 40, height: 40)
                    .shadow(color: Theme.Palette.auroraCyan.opacity(0.7), radius: 4)
                    .opacity(0.6 + 0.4 * pulse)
                    .scaleEffect(1 + 0.04 * pulse)
                // Little "new" dot at the top-right of the ring.
                Circle()
                    .fill(Theme.Palette.auroraCyan)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().strokeBorder(Theme.Palette.obsidian1, lineWidth: 1.2))
                    .shadow(color: Theme.Palette.auroraCyan, radius: 3)
                    .offset(x: 15, y: -15)
            }
            .allowsHitTesting(false)
        }
    }
}
