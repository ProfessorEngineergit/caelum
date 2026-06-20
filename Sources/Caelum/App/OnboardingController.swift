import AppKit
import SwiftUI

/// A borderless window that can still become key, so the API-key field works.
private final class OnboardingWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// Presents the cinematic first-run onboarding as a full-screen takeover window
/// (above the menu bar, Arc-style), fading in from black with ambient audio and
/// fading out to reveal the freshly-set wallpaper.
@MainActor
final class OnboardingController {
    private var window: NSWindow?
    private let audio = OnboardingAudio()
    private let onFinish: (String) -> Void

    init(onFinish: @escaping (String) -> Void) { self.onFinish = onFinish }

    var isShowing: Bool { window != nil }

    func present() {
        guard window == nil, let screen = NSScreen.main else { return }

        let window = OnboardingWindow(contentRect: screen.frame, styleMask: [.borderless],
                                      backing: .buffered, defer: false, screen: screen)
        window.level = .screenSaver                  // cover the menu bar — full takeover
        window.isOpaque = true
        window.backgroundColor = .black
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        window.hasShadow = false
        window.isReleasedWhenClosed = false

        let root = OnboardingView(
            onComplete: { [weak self] key in self?.finish(key) },
            onChime: { [weak self] soft in self?.audio.chime(soft: soft) },
            onBoom: { [weak self] in self?.audio.boom() })
        let hosting = NSHostingView(rootView: root)
        hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
        hosting.autoresizingMask = [.width, .height]
        window.contentView = hosting

        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        self.window = window

        audio.start()
        // Snap to black fast ("springt auf den Desktop, man sieht nichts"); the view
        // then holds black briefly before blooming the nebula with the boom.
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.35
            window.animator().alphaValue = 1
        }
    }

    private func finish(_ apiKey: String) {
        audio.stop()
        let closing = window
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.8
            closing?.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            closing?.orderOut(nil)
            self?.window = nil
            self?.onFinish(apiKey)
        })
    }
}
