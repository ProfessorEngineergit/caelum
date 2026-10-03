import AppKit
import SwiftUI

/// A borderless window that can still become key, so the setup takes clicks and keys.
private final class IntroWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Shared state between the controller and the setup panel.
@MainActor
final class IntroModel: ObservableObject {
    /// The jump has landed — the setup panel comes in.
    @Published var revealed = false
    /// The panel is on its way out.
    @Published var leaving = false
}

/// The first-run intro, Arc-style: every other app hides, the desktop itself turns
/// liquid and jumps to hyperspace (`WarpView`), and the flash drops you into the
/// setup (`WelcomeView`) — a calm, chrome-less panel over a drifting starfield.
/// When you're done, the stars fade back to your desktop and your apps return.
@MainActor
final class IntroController {
    private var window: NSWindow?
    private var warp: WarpView?
    private var hiddenApps: [NSRunningApplication] = []
    private let model = IntroModel()
    private let audio = OnboardingAudio()
    private let appState: AppState
    private let onFinish: () -> Void

    init(appState: AppState, onFinish: @escaping () -> Void) {
        self.appState = appState
        self.onFinish = onFinish
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

        let warp = WarpView(frame: frame, wallpaper: WarpView.desktopImage(for: screen))
        if let warp {
            warp.autoresizingMask = [.width, .height]
            warp.onFlash = { [weak self] in self?.land() }
            container.addSubview(warp)
            self.warp = warp
        }

        let setup = WelcomeView(
            app: appState,
            model: model,
            onChime: { [weak self] in self?.audio.chime(soft: true) },
            onComplete: { [weak self] in self?.finish() })
        let hosting = NSHostingView(rootView: setup)
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

        // The first frame is the wallpaper itself, so fading in just dissolves the
        // desktop icons away before the surface starts to move.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            window.animator().alphaValue = 1
        }

        if warp == nil {
            // No Metal: skip the jump and go straight to the setup.
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: 400_000_000)
                self?.land()
            }
        }
    }

    /// The flash — sound and setup panel arrive on the same frame.
    private func land() {
        guard !model.revealed else { return }
        audio.drone()
        withAnimation(.spring(response: 0.9, dampingFraction: 0.78)) { model.revealed = true }
    }

    private func finish() {
        guard let window, !model.leaving else { return }
        audio.stop()
        withAnimation(.easeIn(duration: 0.35)) { model.leaving = true }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 300_000_000)
            Self.fadeOut(window)
            try? await Task.sleep(nanoseconds: 950_000_000)
            self?.close()
        }
    }

    /// Synchronous on purpose: inside a Task, Swift would pick the async overload.
    private static func fadeOut(_ window: NSWindow) {
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.9
            window.animator().alphaValue = 0
        }
    }

    private func close() {
        warp?.isPaused = true
        window?.orderOut(nil)
        window = nil
        warp = nil
        hiddenApps.forEach { _ = $0.unhide() }
        hiddenApps = []
        onFinish()
    }
}
