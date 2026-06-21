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
                } else if isApplied {
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

    /// How long the ring takes to travel the full border. Matches the real time
    /// macOS takes to actually swap the desktop image from cache (~1.7 s), so the
    /// bar filling, the desktop change and the chime all complete together.
    private let ringDuration: Double = 1.7

    @ViewBuilder private var ringOverlay: some View {
        if isRingAnimating {
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusButton, style: .continuous)
                .trim(from: 0, to: ringProgress)
                .stroke(Theme.Palette.textPrimary,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .padding(1.25)   // keep the stroke fully inside the pill edge
                .allowsHitTesting(false)
        }
    }

    /// The line sweeps around the button border over the same ~1.7 s the OS takes
    /// to actually apply the wallpaper. The set runs off the main thread in
    /// parallel, so the sweep stays smooth; when both the sweep and the set are
    /// done, the chime rings and the button confirms "On Your Desktop" — together.
    private func startRingAnimation() {
        isRingAnimating = true
        ringProgress = 0
        // Let the overlay mount at 0 this runloop, then animate the sweep next tick
        // (animating in the same pass the view is inserted can skip the sweep).
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: ringDuration)) { ringProgress = 1 }
        }
        Task { @MainActor in
            let start = Date()
            await app.applyWallpaperNow(playChime: false)   // real set, off-main
            // Hold until the ring has visually finished its full 1.7 s sweep, so
            // the bar, the desktop change and the chime all land at the same moment.
            let elapsed = Date().timeIntervalSince(start)
            if elapsed < ringDuration {
                try? await Task.sleep(nanoseconds: UInt64((ringDuration - elapsed) * 1_000_000_000))
            }
            if Preferences.shared.chimeOnUpdate { WallpaperChime.shared.play() }
            try? await Task.sleep(nanoseconds: 120_000_000)   // brief hold, then reset
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
