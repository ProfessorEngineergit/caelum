import SwiftUI

/// The primary actions: a prominent aurora "Set as Wallpaper" pill plus a row
/// of glass icon buttons (shuffle, explanation, save, open original).
struct ControlDeck: View {
    @EnvironmentObject var app: AppState

    private var isApplied: Bool { app.wallpaperAppliedID == app.current?.id }
    private var isVideo: Bool { app.current?.isVideo == true }
    private var canShuffle: Bool { app.activeSourceID != "apod" && app.phase == .ready }

    var body: some View {
        VStack(spacing: Theme.Metrics.space3) {
            primaryButton
            HStack(spacing: Theme.Metrics.space3) {
                iconButton("shuffle", "Shuffle", disabled: !canShuffle) { app.shuffleNext() }
                iconButton("text.alignleft", "Explanation",
                           disabled: app.current?.explanation == nil) {
                    withAnimation(Theme.Motion.bouncy) { app.showExplanation = true }
                }
                iconButton("arrow.up.forward.app", "Open original page",
                           disabled: app.current?.pageURL == nil) { app.openSourcePage() }
            }
        }
    }

    @ViewBuilder private var primaryButton: some View {
        if isVideo {
            Button { app.openSourcePage() } label: {
                Label("Watch Today's Video", systemImage: "play.circle.fill")
            }
            .buttonStyle(AuroraPillButtonStyle(filled: false))
        } else {
            Button { app.setWallpaper() } label: {
                if app.isApplyingWallpaper {
                    Label("Setting wallpaper…", systemImage: "circle.dotted")
                } else if !app.isCurrentWallpaperReady && app.isPreparingCurrentWallpaper {
                    Label("Preparing wallpaper…", systemImage: "arrow.down.circle.fill")
                } else if !app.isCurrentWallpaperReady {
                    Label("Wallpaper unavailable", systemImage: "exclamationmark.triangle.fill")
                } else if isApplied {
                    Label("On Your Desktop", systemImage: "checkmark.circle.fill")
                } else {
                    Label("Set as Wallpaper", systemImage: "photo.fill.on.rectangle.fill")
                }
            }
            .buttonStyle(AuroraPillButtonStyle(filled: !isApplied))
            .disabled(app.phase != .ready || !app.isCurrentWallpaperReady)
        }
    }

    private func iconButton(_ symbol: String, _ help: String,
                            disabled: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) { Image(systemName: symbol) }
            .buttonStyle(GlassIconButtonStyle(tint: Theme.Palette.textPrimary))
            .frame(maxWidth: .infinity)
            .opacity(disabled ? 0.35 : 1)
            .disabled(disabled)
            .help(help)
    }
}
