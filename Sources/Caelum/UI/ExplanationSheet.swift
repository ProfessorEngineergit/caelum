import SwiftUI

/// Slide-up reader for the current image's long-form description — beautiful
/// long-text typography over near-opaque obsidian for legibility.
struct ExplanationSheet: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.Palette.hairline)
            ScrollView {
                VStack(alignment: .leading, spacing: Theme.Metrics.space4) {
                    if let explanation = app.current?.explanation, !explanation.isEmpty {
                        Text(explanation)
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Palette.textPrimary.opacity(0.92))
                            .lineSpacing(5)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text("No description available for this image.")
                            .font(Theme.Fonts.body(13))
                            .foregroundStyle(Theme.Palette.textSecondary)
                    }

                    if let credit = app.current?.credit, !credit.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Credit").microLabel()
                            Text(credit)
                                .font(Theme.Fonts.body(12))
                                .foregroundStyle(Theme.Palette.textSecondary)
                        }
                    }

                    if app.current?.pageURL != nil {
                        Button { app.openSourcePage() } label: {
                            Label("Open original", systemImage: "arrow.up.forward.app")
                        }
                        .buttonStyle(AuroraPillButtonStyle(filled: false))
                    }
                }
                .padding(Theme.Metrics.space5)
            }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight)
        .background(Theme.Palette.obsidian1.opacity(0.975))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Theme.Metrics.space3) {
            VStack(alignment: .leading, spacing: 3) {
                Text(app.activeSource.name).microLabel(app.accent)
                Text(app.current?.title ?? "")
                    .font(Theme.Fonts.display(18))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(3)
                if let date = app.current?.date {
                    Text(CaelumDates.display(date))
                        .font(Theme.Fonts.mono(10))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
            }
            Spacer()
            Button {
                withAnimation(Theme.Motion.bouncy) { app.showExplanation = false }
            } label: { Image(systemName: "xmark") }
                .buttonStyle(GlassIconButtonStyle(size: 34))
        }
        .padding(Theme.Metrics.space5)
    }
}
