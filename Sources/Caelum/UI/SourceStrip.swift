import SwiftUI

/// 3-column grid of all image sources. Each cell shows the source glyph,
/// name, subtitle and a resolution badge. The active source is highlighted
/// with the aurora gradient; the rest are quiet glass.
struct SourceStrip: View {
    @EnvironmentObject var app: AppState
    @Environment(\.isSnapshot) private var isSnapshot

    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.space2) {
            Text("Sources").microLabel()
                .padding(.horizontal, 2)

            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(app.sources, id: \.id) { source in
                    SourceCell(
                        source: source,
                        active: source.id == app.activeSourceID,
                        accent: app.accent
                    ) {
                        app.selectSource(source.id)
                    }
                }
            }
        }
    }
}

private struct SourceCell: View {
    let source: ImageSource
    let active: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Icon
                ZStack {
                    Circle()
                        .fill(active
                            ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                            : AnyShapeStyle(Theme.Palette.obsidian3.opacity(0.8)))
                        .frame(width: 36, height: 36)
                    Image(systemName: source.symbol)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(active ? Color.black : Theme.Palette.textSecondary)
                }
                .shadow(color: active ? accent.opacity(0.5) : .clear, radius: 8, y: 2)

                // Name
                Text(source.name)
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
                    .foregroundStyle(active ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                // Resolution badge
                resBadge(source.typicalResolution)
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusChip, style: .continuous)
                    .fill(active
                        ? AnyShapeStyle(Theme.Palette.obsidian2.opacity(0.9))
                        : AnyShapeStyle(Theme.Palette.obsidian1.opacity(0.5)))
            )
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Metrics.radiusChip, style: .continuous)
                    .strokeBorder(
                        active ? AnyShapeStyle(Theme.Gradients.auroraHorizontal.opacity(0.5))
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
            .padding(.horizontal, 5).padding(.vertical, 2)
            .background(Capsule().fill(c.opacity(0.12)))
            .overlay(Capsule().strokeBorder(c.opacity(0.25), lineWidth: 0.5))
    }
}
