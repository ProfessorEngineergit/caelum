import SwiftUI

/// The primary actions: a prominent aurora "Set as Wallpaper" pill plus a row
/// of glass icon buttons (shuffle, explanation, save, open original).
struct ControlDeck: View {
    @EnvironmentObject var app: AppState

    @State private var ringProgress: CGFloat = 0
    @State private var isRingAnimating = false

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
            Button {
                guard !isRingAnimating else { return }
                startRingAnimation()
            } label: {
                if isRingAnimating || app.isApplyingWallpaper {
                    Label("Setting wallpaper…", systemImage: "circle.dotted")
                } else if !app.isCurrentWallpaperReady && app.isPreparingCurrentWallpaper {
                    Label("Preparing wallpaper…", systemImage: "arrow.down.circle.fill")
                } else if !app.isCurrentWallpaperReady {
                    Label("Wallpaper unavailable", systemImage: "exclamationmark.triangle.fill")
                } else if isApplied && !isRingAnimating {
                    Label("On Your Desktop", systemImage: "checkmark.circle.fill")
                } else {
                    Label("Set as Wallpaper", systemImage: "photo.fill.on.rectangle.fill")
                }
            }
            .buttonStyle(AuroraPillButtonStyle(filled: !isApplied && !isRingAnimating))
            .disabled(app.phase != .ready || !app.isCurrentWallpaperReady || isRingAnimating)
            .overlay(ringOverlay)
        }
    }

    @ViewBuilder private var ringOverlay: some View {
        if isRingAnimating {
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusButton, style: .continuous)
                .trim(from: 0, to: ringProgress)
                .stroke(app.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .animation(.easeInOut(duration: 0.9), value: ringProgress)
        }
    }

    private func startRingAnimation() {
        isRingAnimating = true
        ringProgress = 0
        // Apply wallpaper immediately (fast, ~200 ms); chime fires when ring completes.
        app.setWallpaperSilently()
        // Ring sweeps to completion over ~900 ms.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            withAnimation(.easeInOut(duration: 0.9)) { ringProgress = 1 }
        }
        // After ring is full: chime, then fade ring out.
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 980_000_000)   // 980 ms — ring done
            if Preferences.shared.chimeOnUpdate { WallpaperChime.shared.play() }
            try? await Task.sleep(nanoseconds: 160_000_000)   // brief hold, then reset
            withAnimation(Theme.Motion.snappy) {
                isRingAnimating = false
                ringProgress = 0
            }
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
