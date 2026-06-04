import SwiftUI

/// The viewport's hero: today's image bleeds edge-to-edge at the top and
/// **dissolves** (loses opacity) into the panel background from where the text
/// begins — a seamless blend into the controls below, with no divider line and
/// no opaque base of its own (the shared GlassBackground shows through the fade).
struct HeroView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var kenBurns = false

    /// Vertical alpha mask: fully visible at the top, fading to transparent
    /// toward the bottom, starting roughly where the title sits.
    private var fadeMask: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: .black,               location: 0.00),
                .init(color: .black,               location: 0.42),
                .init(color: .black.opacity(0.55), location: 0.66),
                .init(color: .black.opacity(0.18), location: 0.85),
                .init(color: .black.opacity(0.0),  location: 1.00),
            ],
            startPoint: .top, endPoint: .bottom
        )
    }

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = app.heroImage {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.heroHeight)
                    .clipped()
                    .scaleEffect(kenBurns ? 1.07 : 1.0)
                    .mask(fadeMask)
                    .id(app.current?.id)
                    .transition(.opacity.animation(Theme.Motion.gentle))
                    .onAppear {
                        guard !isSnapshot else { return }
                        withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
                            kenBurns = true
                        }
                    }
            }

            content
                .padding(.horizontal, Theme.Metrics.space4)
                .padding(.bottom, Theme.Metrics.space2)

            if app.phase == .loading { loadingOverlay }
            if app.phase == .error   { errorOverlay   }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.heroHeight)
        .clipped()
    }

    // MARK: - Content overlay

    private var content: some View {
        VStack(alignment: .leading, spacing: 5) {
            Spacer(minLength: 0)

            HStack(spacing: 8) {
                Image(systemName: app.activeSource.symbol)
                    .font(.system(size: 9, weight: .bold))
                Text(app.activeSource.name)
                    .microLabel(app.accent)
                    .foregroundStyle(app.accent)

                resolutionBadge(app.actualResolution ?? app.current?.resolution ?? app.activeSource.typicalResolution)

                if app.current?.isVideo == true {
                    Text("VIDEO").microLabel(Theme.Palette.warning)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Capsule().fill(Theme.Palette.warning.opacity(0.16)))
                }
                Spacer(minLength: 0)
            }
            .shadow(color: .black.opacity(0.6), radius: 5, y: 1)

            Text(app.current?.title ?? "Caelum")
                .font(Theme.Fonts.display(21))
                .foregroundStyle(Theme.Palette.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .shadow(color: .black.opacity(0.8), radius: 10, y: 2)

            HStack(spacing: 8) {
                if let date = app.current?.date {
                    Text(CaelumDates.display(date)).font(Theme.Fonts.mono(10))
                }
                if let credit = app.current?.credit, !credit.isEmpty {
                    Text("· \(credit)").font(Theme.Fonts.mono(10)).lineLimit(1)
                }
            }
            .foregroundStyle(Theme.Palette.textSecondary)
            .shadow(color: .black.opacity(0.6), radius: 4, y: 1)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func resolutionBadge(_ hint: ResolutionHint) -> some View {
        let c = Color(hex: hint.accentHex)
        Text(hint.rawValue)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .tracking(0.8)
            .foregroundStyle(c)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Capsule().fill(c.opacity(0.18)))
            .overlay(Capsule().strokeBorder(c.opacity(0.35), lineWidth: 0.5))
    }

    // MARK: - Loading / Error states

    private var loadingOverlay: some View {
        VStack(spacing: 12) {
            OrbitalLoader(tint: app.accent)
            Text("Summoning the cosmos…").microLabel()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        .background(Theme.Palette.obsidian0.opacity(0.55))
    }
}
