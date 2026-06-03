import SwiftUI

/// The viewport's hero: today's image with a legibility scrim, the source
/// micro-label, the title and the metadata line. Cross-fades between images
/// and breathes with a slow ken-burns drift.
struct HeroView: View {
    @EnvironmentObject var app: AppState
    @State private var kenBurns = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            Theme.Palette.obsidian0

            if let image = app.heroImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(kenBurns ? 1.09 : 1.0)
                    .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.heroHeight)
                    .clipped()
                    .id(app.current?.id)
                    .transition(.opacity)
                    .onAppear { withAnimation(.easeInOut(duration: 20).repeatForever(autoreverses: true)) { kenBurns = true } }
            }

            Theme.Gradients.heroScrim()

            content
                .padding(Theme.Metrics.space4)

            if app.phase == .loading { loadingOverlay }
            if app.phase == .error { errorOverlay }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.heroHeight)
        .clipped()
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            Spacer(minLength: 0)
            HStack(spacing: 8) {
                Image(systemName: app.activeSource.symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(app.activeSource.name)
                    .microLabel(app.accent)
                if app.current?.isVideo == true {
                    Text("VIDEO").microLabel(Theme.Palette.warning)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Palette.warning.opacity(0.16)))
                }
            }
            .foregroundStyle(app.accent)

            Text(app.current?.title ?? "Caelum")
                .font(Theme.Fonts.display(21))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.6), radius: 8, y: 2)

            HStack(spacing: 8) {
                if let date = app.current?.date {
                    Text(CaelumDates.display(date)).font(Theme.Fonts.mono(10))
                }
                if let credit = app.current?.credit, !credit.isEmpty {
                    Text("· \(credit)").font(Theme.Fonts.mono(10)).lineLimit(1)
                }
            }
            .foregroundStyle(Theme.Palette.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            OrbitalLoader(tint: app.accent)
            Text("Summoning the cosmos…").microLabel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.obsidian0.opacity(0.55))
    }

    private var errorOverlay: some View {
        VStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(Theme.Palette.warning)
            Text(app.errorText ?? "Something went wrong.")
                .font(Theme.Fonts.body(12))
                .foregroundStyle(Theme.Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
            Button("Try again") { app.refresh() }
                .buttonStyle(.plain)
                .font(Theme.Fonts.title(12))
                .foregroundStyle(app.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.obsidian0.opacity(0.82))
    }
}
