import AppKit
import SwiftUI

/// A borderless window that can still become key, so the setup takes clicks and keys.
private final class IntroWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shared state between the controller and the panel (`WelcomeView`).
@MainActor
final class IntroModel: ObservableObject {
    enum Mode { case intro, update }

    let mode: Mode
    /// The jump has landed — the panel comes in.
    @Published var revealed = false
    /// The panel is collapsing into light (outro) or fading away (closed).
    @Published var leaving = false
    /// Update screen: versions and the commit subjects between them.
    @Published var fromVersion = ""
    @Published var toVersion = ""
    @Published var changes: [String] = []

    init(mode: Mode) { self.mode = mode }
}

/// The intro window, in two modes:
///
/// * **intro** (first launch, or "Replay Intro"): every other app hides, the
///   desktop itself makes the jump to hyperspace (`WarpView`), and the flash lands
///   in the setup. "Enter Caelum" sets the wallpaper and plays the outro — images
///   from the library fly past in the tunnel, the biggest flash, and the new
///   wallpaper washes in from the centre.
/// * **update** (first launch after an update): the same jump lands on the
///   update screen with the release's changes; Continue flies back to the desktop.
///
/// The Windows/Linux twin is desktop/src/main/intro.js + src/renderer/intro.
@MainActor
final class IntroController {
    /// Bump to show the intro again to everyone once.
    static let introVersion = 2

    private var window: NSWindow?
    private var warp: WarpView?
    private var cardLayer: CALayer?
    private struct Card {
        let layer: CALayer
        let angle: CGFloat
        let radius: CGFloat
        let spawn: Float
        let life: Float
        let tilt: CGFloat
    }
    private var cards: [Card] = []
    private var hiddenApps: [NSRunningApplication] = []
    private let model: IntroModel
    private let audio = IntroAudio()
    private let appState: AppState
    private let onFinish: () -> Void

    init(appState: AppState, mode: IntroModel.Mode = .intro,
         update: (from: String, to: String)? = nil, onFinish: @escaping () -> Void) {
        self.appState = appState
        self.model = IntroModel(mode: mode)
        self.onFinish = onFinish
        if let update {
            model.fromVersion = update.from
            model.toVersion = update.to
            Task { [weak self] in
                let changes = await Self.changes(from: update.from, to: update.to)
                self?.model.changes = changes
            }
        }
    }

    func present() {
        guard window == nil, let screen = NSScreen.main else { return }
        NSApp.activate(ignoringOtherApps: true)
        hideOtherApps()
        // Let the apps' hide animations clear the desktop before the jump starts.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 700_000_000)
            self?.open(on: screen)
        }
    }

    private func hideOtherApps() {
        let me = NSRunningApplication.current
        hiddenApps = NSWorkspace.shared.runningApplications.filter {
            $0.activationPolicy == .regular && !$0.isHidden && $0 != me
        }
        hiddenApps.forEach { _ = $0.hide() }
    }

    private func open(on screen: NSScreen) {
        let frame = NSRect(origin: .zero, size: screen.frame.size)
        let window = IntroWindow(contentRect: screen.frame, styleMask: [.borderless],
                                 backing: .buffered, defer: false, screen: screen)
        window.level = .screenSaver                  // above the menu bar and the Dock
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        let container = NSView(frame: frame)
        container.autoresizingMask = [.width, .height]
        container.wantsLayer = true

        let warp = WarpView(frame: frame, wallpaper: WarpView.desktopImage(for: screen))
        if let warp {
            warp.autoresizingMask = [.width, .height]
            warp.onFlash = { [weak self] in self?.land() }
            warp.onFrame = { [weak self] _, exitTime in self?.drawCards(exitTime) }
            warp.onExitDone = { [weak self] in self?.close() }
            container.addSubview(warp)
            self.warp = warp
        }

        // The library's images, flying past in the outro (3D, behind the panel).
        let cardHost = NSView(frame: frame)
        cardHost.autoresizingMask = [.width, .height]
        cardHost.wantsLayer = true
        var perspective = CATransform3DIdentity
        perspective.m34 = -1 / 900
        cardHost.layer?.sublayerTransform = perspective
        container.addSubview(cardHost)
        cardLayer = cardHost.layer

        let panel = WelcomeView(
            app: appState,
            model: model,
            audio: audio,
            onEnter: { [weak self] in self?.enter() },
            onClose: { [weak self] in self?.quit() })
        let hosting = NSHostingView(rootView: panel)
        hosting.frame = frame
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)

        window.contentView = container
        window.alphaValue = 0
        warp?.restart()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window
        audio.start()
        audio.play(model.mode == .update ? "update" : "intro")

        // The first frame is the wallpaper itself, so fading in just dissolves the
        // desktop icons away before the surface starts to move.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            window.animator().alphaValue = 1
        }

        if warp == nil {
            // No Metal: skip the jump and go straight to the panel.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self?.land()
            }
        }
    }

    /// The flash — the panel arrives on the same frame as the impact.
    private func land() {
        guard !model.revealed else { return }
        withAnimation(.spring(response: 0.9, dampingFraction: 0.72)) { model.revealed = true }
        audio.startBed()
    }

    // MARK: - Outro

    /// "Enter Caelum" / "Continue": the big jump back to the desktop.
    private func enter() {
        guard !model.leaving else { return }
        withAnimation(.easeIn(duration: 0.55)) { model.leaving = true }
        audio.stopBed(duration: 0.6)
        audio.play("outro")
        buildCards()
        guard let warp else { quit(); return }
        warp.beginExit()
        Task { [weak self] in
            guard let self else { return }
            // Set the wallpaper now (setup), the jump lands on it; after an update
            // it simply lands back on the desktop as it is.
            if self.model.mode == .intro {
                await self.appState.applyWallpaperNow(playChime: false)
            }
            let landing = Preferences.shared.appliedWallpaperPath.flatMap { WarpView.image(at: URL(fileURLWithPath: $0)) }
                ?? NSScreen.main.flatMap { WarpView.desktopImage(for: $0) }
            warp.setLanding(landing)
        }
    }

    private func buildCards() {
        guard let host = cardLayer else { return }
        let files = ImageCache.shared.cachedFiles().prefix(16)
        let size = CGSize(width: 340, height: 212)
        cards = files.enumerated().compactMap { (index: Int, file: URL) -> Card? in
            guard let image = ImageCache.shared.downsampled(file, maxPixel: 700),
                  let cg = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
            let layer = CALayer()
            layer.bounds = CGRect(origin: .zero, size: size)
            layer.position = CGPoint(x: host.bounds.midX, y: host.bounds.midY)
            layer.contents = cg
            layer.contentsGravity = .resizeAspectFill
            layer.cornerRadius = 14
            layer.masksToBounds = true
            layer.borderWidth = 1
            layer.borderColor = NSColor.white.withAlphaComponent(0.25).cgColor
            layer.opacity = 0
            host.addSublayer(layer)
            let i = CGFloat(index)
            let spawn = 1.0 + Float(index) / Float(max(1, files.count - 1)) * 3.2
            return Card(layer: layer,
                        angle: (i * 2.399963).truncatingRemainder(dividingBy: .pi * 2),   // golden-angle spread
                        radius: 420 + CGFloat((index * 97) % 5) * 90,
                        spawn: spawn,
                        life: 1.7 - (spawn - 1.0) * 0.22,
                        tilt: (index % 2 == 1 ? 1 : -1) * (6 + CGFloat(index % 4) * 3))
        }
    }

    /// Positions the cards for outro time `te` — the same path as the desktop app.
    private func drawCards(_ te: Float) {
        guard te >= 0, !cards.isEmpty else { return }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        for card in cards {
            let k = (te - card.spawn) / card.life
            guard k >= 0, k <= 1 else { card.layer.opacity = 0; continue }
            let kk = CGFloat(k)
            let z = -3200 + 4300 * pow(kk, 1.7)
            let x = cos(card.angle) * card.radius * (0.6 + 0.4 * kk)
            let y = sin(card.angle) * card.radius * 0.62 * (0.6 + 0.4 * kk)
            card.layer.opacity = Float(min(min(1, kk / 0.2), min(1, (1 - kk) / 0.12)) * 0.95)
            var transform = CATransform3DMakeTranslation(x, -y, z)
            transform = CATransform3DRotate(transform, card.tilt * (x > 0 ? -1 : 1) * .pi / 180, 0, 1, 0)
            transform = CATransform3DRotate(transform, card.tilt * 0.3 * .pi / 180, 0, 0, 1)
            card.layer.transform = transform
        }
        CATransaction.commit()
    }

    // MARK: - Leaving

    /// Close button / Esc: no jump, just fade back to the desktop.
    private func quit() {
        guard let window, !model.leaving else { return }
        withAnimation(.easeIn(duration: 0.35)) { model.leaving = true }
        audio.stopBed(duration: 0.4)
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 250_000_000)
            Self.fadeOut(window)
            try? await Task.sleep(nanoseconds: 750_000_000)
            self?.close()
        }
    }

    /// Synchronous on purpose: inside a Task, Swift would pick the async overload.
    private static func fadeOut(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.7
            window.animator().alphaValue = 0
        }
    }

    private func close() {
        guard window != nil else { return }
        warp?.isPaused = true
        window?.orderOut(nil)
        window = nil
        warp = nil
        cards = []
        hiddenApps.forEach { _ = $0.unhide() }
        hiddenApps = []
        audio.stop(after: 4)        // let the last tail ring out
        onFinish()
    }

    // MARK: - Release notes

    private struct Comparison: Decodable {
        struct Commit: Decodable {
            struct Detail: Decodable { let message: String }
            let commit: Detail
        }
        let commits: [Commit]
    }

    /// Commit subjects between two releases, from GitHub — the update screen's lines.
    static func changes(from: String, to: String) async -> [String] {
        guard let url = URL(string: "https://api.github.com/repos/ProfessorEngineergit/caelum/compare/v\(from)...v\(to)"),
              let comparison = try? await HTTPClient.json(Comparison.self, from: url) else { return [] }
        let subjects = comparison.commits
            .map { $0.commit.message.split(separator: "\n").first.map(String.init) ?? "" }
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("Merge pull request") && !$0.hasPrefix("Merge branch") }
        return Array(subjects.reversed().prefix(6))
    }
}
