import SwiftUI

/// The viewport's hero: today's image bleeds edge-to-edge at the top and
/// **dissolves** (loses opacity) into the panel background from where the text
/// begins — a seamless blend into the controls below, with no divider line and
/// no opaque base of its own (the shared GlassBackground shows through the fade).
struct HeroView: View {
    @EnvironmentObject var app: AppState
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var kenBurns = false

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            if let image = app.heroImage {
                heroLayers(image)
                    .id(app.current?.id)
                    .transition(.opacity.animation(.easeOut(duration: 0.22)))
                    .onAppear {
                        guard !isSnapshot else { return }
                        withAnimation(.easeInOut(duration: 24).repeatForever(autoreverses: true)) {
                            kenBurns = true
                        }
                    }
            }

            // Darken the lower third for title legibility; fades out at the very
            // bottom so it doesn't add a band over the panel background.
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: .clear, location: 0.42),
                    .init(color: .black.opacity(0.38), location: 0.74),
                    .init(color: .black.opacity(0.0), location: 1.0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .allowsHitTesting(false)

            content
                .padding(.horizontal, Theme.Metrics.space4)
                .padding(.bottom, Theme.Metrics.space2)

            if app.phase == .loading { loadingOverlay }
            if app.phase == .error   { errorOverlay   }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.heroHeight)
        .clipped()
    }

    /// A single sharp image whose opacity fades to transparent toward the bottom
    /// (no blur) — it dissolves cleanly into the panel background, no divider line.
    @ViewBuilder
    private func heroLayers(_ image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .interpolation(.high)
            .antialiased(true)
            .aspectRatio(contentMode: .fill)
            .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.heroHeight)
            .clipped()
            .scaleEffect(kenBurns ? 1.07 : 1.0)
            .mask(LinearGradient(
                stops: [
                    .init(color: .black, location: 0.00),
                    .init(color: .black, location: 0.50),
                    .init(color: .black.opacity(0.45), location: 0.76),
                    .init(color: .black.opacity(0.0), location: 0.98),
                ],
                startPoint: .top, endPoint: .bottom))
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

    @ViewBuilder
    private var loadingOverlay: some View {
        if app.heroImage == nil {
            // First load — full centered loader.
            VStack(spacing: 12) {
                OrbitalLoader(tint: app.accent)
                Text("Summoning the cosmos…").microLabel()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            // Reloading — keep the previous image, show a quiet corner spinner.
            VStack {
                HStack {
                    Spacer()
                    OrbitalLoader(tint: app.accent, size: 20)
                        .padding(12)
                }
                Spacer()
            }
        }
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
            Text("Tap to retry")
                .font(Theme.Fonts.title(12))
                .foregroundStyle(app.accent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Theme.Palette.obsidian0.opacity(0.6))
        .contentShape(Rectangle())
        .onTapGesture { app.refresh() }
    }
}
