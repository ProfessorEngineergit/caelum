import SwiftUI

/// "The Viewport" — the entire menu-bar panel. A fixed hero on top, a fixed
/// control deck, then a **scrollable** source grid that fills the remaining
/// space, and a fixed footer micro-bar. Slide-up overlays for explanation and
/// settings.
struct PopoverView: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        ZStack {
            GlassBackground(accent: app.accent)

            VStack(spacing: 0) {
                HeroView()                               // fixed 220
                if app.isWarmingUp {
                    WarmingBanner()
                        .padding(.horizontal, Theme.Metrics.space4)
                        .padding(.top, Theme.Metrics.space3)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
                if Preferences.shared.usingDemoKey {
                    DemoKeyBanner { withAnimation(Theme.Motion.gentle) { app.showSettings = true } }
                        .padding(.horizontal, Theme.Metrics.space4)
                        .padding(.top, Theme.Metrics.space3)
                }
                ControlDeck()                            // fixed
                    .padding(.horizontal, Theme.Metrics.space4)
                    .padding(.top, Theme.Metrics.space4)
                    .padding(.bottom, Theme.Metrics.space3)
                SourceStrip()                            // flexible — scrolls
                FooterBar()                              // fixed bottom
            }

            if app.showExplanation {
                ExplanationSheet()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(2)
            }
            if app.showSettings {
                SettingsView(
                    scheduler: app.scheduler,
                    onDismiss: { withAnimation(Theme.Motion.gentle) { app.showSettings = false } }
                )
                .transition(.opacity)
                .zIndex(2)
            }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
        .environment(\.colorScheme, .dark)
    }
}

/// Slim, info-styled hint shown on a cold first run while the cache warms; fades
/// itself out once things are ready (see AppState.beginWarmup).
private struct WarmingBanner: View {
    var body: some View {
        HStack(spacing: 8) {
            OrbitalLoader(tint: Theme.Palette.auroraCyan, size: 13)
            Text("Getting things ready — the first few images may be a little slow")
                .font(Theme.Fonts.body(11))
                .lineLimit(1).minimumScaleFactor(0.75)
            Spacer(minLength: 0)
        }
        .foregroundStyle(Theme.Palette.textSecondary)
        .padding(.horizontal, 12).padding(.vertical, 8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Theme.Palette.auroraCyan.opacity(0.10)))
        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
            .strokeBorder(Theme.Palette.auroraCyan.opacity(0.22), lineWidth: 1))
    }
}

/// Slim hint shown while running on the shared DEMO_KEY — taps through to Settings.
private struct DemoKeyBanner: View {
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "key.fill").font(.system(size: 10, weight: .bold))
                Text("Using the shared demo key — add yours for faster APOD")
                    .font(Theme.Fonts.body(11))
                    .lineLimit(1).minimumScaleFactor(0.8)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
            }
            .foregroundStyle(Theme.Palette.warning)
            .padding(.horizontal, 12).padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.Palette.warning.opacity(0.12)))
            .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Theme.Palette.warning.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// Footer micro-bar: settings, ambient, refresh — wordmark — quit.
private struct FooterBar: View {
    @EnvironmentObject var app: AppState

    var body: some View {
        HStack(spacing: Theme.Metrics.space2) {
            footerButton("gearshape.fill", "Settings") {
                withAnimation(Theme.Motion.gentle) { app.showSettings = true }
            }

            Spacer()
            Text("CAELUM")
                .font(Theme.Fonts.micro(10)).tracking(3)
                .foregroundStyle(Theme.Palette.textTertiary)
            Spacer()

            footerButton("power", "Quit Caelum") { NSApp.terminate(nil) }
        }
        .padding(.horizontal, Theme.Metrics.space4)
        .padding(.vertical, Theme.Metrics.space3)
        .background(
            Rectangle().fill(Theme.Palette.obsidian0.opacity(0.55))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Palette.hairline), alignment: .top)
        )
    }

    private func footerButton(_ symbol: String, _ help: String,
                              action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(GlassIconButtonStyle(size: 34))
            .help(help)
    }
}
