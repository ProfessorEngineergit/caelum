import SwiftUI

/// Horizontally scrollable strip of the 10 source chips. The active source is
/// filled with the aurora gradient; the rest are quiet glass.
struct SourceStrip: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.space2) {
            Text("Sources").microLabel()
                .padding(.horizontal, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Theme.Metrics.space2) {
                    ForEach(app.sources, id: \.id) { source in
                        SourceChip(source: source,
                                   active: source.id == app.activeSourceID,
                                   accent: app.accent) {
                            app.selectSource(source.id)
                        }
                    }
                }
                .padding(.vertical, 2)
            }
        }
    }
}

private struct SourceChip: View {
    let source: ImageSource
    let active: Bool
    let accent: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: source.symbol)
                    .font(.system(size: 11, weight: .bold))
                Text(source.name)
                    .font(Theme.Fonts.title(12))
                    .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .foregroundStyle(active ? Color.black : Theme.Palette.textSecondary)
            .background(
                Capsule().fill(active
                    ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                    : AnyShapeStyle(Theme.Palette.obsidian2.opacity(0.6)))
            )
            .overlay(
                Capsule().strokeBorder(
                    active ? Color.white.opacity(0.22) : Theme.Palette.hairline,
                    lineWidth: 1)
            )
            .shadow(color: active ? accent.opacity(0.4) : .clear, radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
