import AppKit
import SwiftUI

/// A borderless `NSPanel` that can still become key (so text fields work).
final class CaelumPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

/// Owns the menu-bar status item and the floating obsidian-glass panel that
/// hosts the SwiftUI viewport. Handles toggle, positioning, dismiss-on-
/// outside-click, the right-click fallback menu, and the brand-glyph animation.
@MainActor
final class StatusItemController: NSObject {
    private let appState: AppState
    private let statusItem: NSStatusItem
    private let panel: CaelumPanel
    private var glassContainer: NSView?
    private var hostingView: NSView?
    private var clickMonitor: Any?
    private var glyphTimer: Timer?

    /// Transparent margin around the content so the soft drop shadow has room.
    /// Kept tight so the window doesn't swallow clicks far around the visible card.
    private static let shadowMargin: CGFloat = 20

    private var contentWidth: CGFloat { Theme.Metrics.popoverWidth }
    private var contentHeight: CGFloat { Theme.Metrics.popoverHeight }

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel = CaelumPanel(
            contentRect: NSRect(x: 0, y: 0,
                                width: Theme.Metrics.popoverWidth + Self.shadowMargin * 2,
                                height: Theme.Metrics.popoverHeight + Self.shadowMargin * 2),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered, defer: true)
        super.init()
        configureStatusItem()
        configurePanel()
    }

    // MARK: - Setup

    private func configureStatusItem() {
        if let button = statusItem.button {
            button.image = BrandGlyph.statusImage()
            button.target = self
            button.action = #selector(togglePanel)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Caelum"
        }
        appState.onImageReady = { [weak self] in self?.animateGlyph() }
    }

    private func configurePanel() {
        panel.isFloatingPanel = true
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = false   // we draw our own rounded shadow (no square "ears")
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .none

        let radius = Theme.Metrics.radiusPanel
        let contentRect = NSRect(x: Self.shadowMargin, y: Self.shadowMargin,
                                 width: contentWidth, height: contentHeight)

        // Wrapper fills the whole (oversized) window; stays transparent.
        let wrapper = NSView(frame: NSRect(x: 0, y: 0,
                                           width: contentWidth + Self.shadowMargin * 2,
                                           height: contentHeight + Self.shadowMargin * 2))
        wrapper.wantsLayer = true

        // Card carries the soft, perfectly-rounded drop shadow (not clipped).
        let card = NSView(frame: contentRect)
        card.wantsLayer = true
        if let layer = card.layer {
            layer.cornerRadius = radius
            layer.cornerCurve = .continuous
            layer.shadowColor = NSColor.black.cgColor
            layer.shadowOpacity = 0.5
            layer.shadowRadius = 13
            layer.shadowOffset = NSSize(width: 0, height: -5)
            layer.shadowPath = CGPath(roundedRect: card.bounds,
                                      cornerWidth: radius, cornerHeight: radius, transform: nil)
            layer.masksToBounds = false
        }

        // Real frosted glass: blurs the desktop behind the panel.
        let effect = NSVisualEffectView(frame: card.bounds)
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = radius
        effect.layer?.cornerCurve = .continuous
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.16).cgColor
        effect.autoresizingMask = [.width, .height]

        card.addSubview(effect)
        wrapper.addSubview(card)
        panel.contentView = wrapper
        glassContainer = effect
    }

    /// Mount the SwiftUI view only while the panel is visible — a menu-bar app
    /// must not run SwiftUI layout/animations in the background when closed.
    private func mountContent() {
        guard hostingView == nil, let container = glassContainer else { return }
        let hosting = NSHostingView(rootView: PopoverView().environmentObject(appState))
        hosting.frame = container.bounds
        hosting.autoresizingMask = [.width, .height]
        container.addSubview(hosting)
        hostingView = hosting
    }

    private func unmountContent() {
        hostingView?.removeFromSuperview()
        hostingView = nil
    }

    // MARK: - Toggle

    @objc private func togglePanel() {
        let event = NSApp.currentEvent
        let isSecondary = event?.type == .rightMouseUp
            || (event?.modifierFlags.contains(.control) ?? false)
        if isSecondary { showContextMenu(); return }
        panel.isVisible ? hidePanel() : showPanel()
    }

    private func showPanel() {
        mountContent()
        positionPanel()
        panel.alphaValue = 0
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        NSAnimationContext.runAnimationGroup { ctx in
            ctx.duration = 0.16
            panel.animator().alphaValue = 1
        }
        installClickMonitor()
    }

    private func hidePanel() {
        removeClickMonitor()
        appState.showSettings = false
        appState.showExplanation = false
        NSAnimationContext.runAnimationGroup({ ctx in
            ctx.duration = 0.13
            panel.animator().alphaValue = 0
        }, completionHandler: { [weak self] in
            Task { @MainActor in
                self?.panel.orderOut(nil)
                self?.unmountContent()
            }
        })
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let onScreen = buttonWindow.convertToScreen(button.convert(button.bounds, to: nil))
        // Position the visible card (inset by shadowMargin), not the whole window.
        var cardX = onScreen.midX - contentWidth / 2
        let cardTopY = onScreen.minY - 6
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let maxX = screen.visibleFrame.maxX - contentWidth - 8
            let minX = screen.visibleFrame.minX + 8
            cardX = min(max(cardX, minX), maxX)
        }
        panel.setFrameOrigin(NSPoint(x: cardX - Self.shadowMargin,
                                     y: (cardTopY - contentHeight) - Self.shadowMargin))
    }

    // MARK: - Dismiss on outside click

    private func installClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            Task { @MainActor in self?.hidePanel() }
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor { NSEvent.removeMonitor(monitor); clickMonitor = nil }
    }

    // MARK: - Right-click fallback menu

    private func showContextMenu() {
        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Quit Caelum",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        if let button = statusItem.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    // MARK: - Brand glyph animation (dot completes one orbit on new image)

    private func animateGlyph() {
        glyphTimer?.invalidate()
        let start = Date()
        glyphTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let progress = min(Date().timeIntervalSince(start) / 1.1, 1.0)
                self.statusItem.button?.image = BrandGlyph.statusImage(dotProgress: 0.1 + progress)
                if progress >= 1.0 { timer.invalidate() }
            }
        }
    }
}
