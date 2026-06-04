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
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .zIndex(2)
            }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
        .environment(\.colorScheme, .dark)
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
            footerButton("arrow.clockwise", "Refresh") { app.refresh() }

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
