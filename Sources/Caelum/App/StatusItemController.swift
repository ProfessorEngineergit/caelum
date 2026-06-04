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
    private var glassContainer: NSVisualEffectView?
    private var hostingView: NSView?
    private var clickMonitor: Any?
    private var glyphTimer: Timer?

    init(appState: AppState) {
        self.appState = appState
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        panel = CaelumPanel(
            contentRect: NSRect(x: 0, y: 0, width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight),
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
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.animationBehavior = .none

        let effect = NSVisualEffectView()
        effect.material = .hudWindow
        effect.blendingMode = .behindWindow
        effect.state = .active
        effect.wantsLayer = true
        effect.layer?.cornerRadius = Theme.Metrics.radiusPanel
        effect.layer?.masksToBounds = true
        effect.layer?.borderWidth = 1
        effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.14).cgColor
        effect.frame = NSRect(x: 0, y: 0, width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight)
        panel.contentView = effect
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
            self?.panel.orderOut(nil)
            self?.unmountContent()
        })
    }

    private func positionPanel() {
        guard let button = statusItem.button, let buttonWindow = button.window else { return }
        let buttonRect = button.convert(button.bounds, to: nil)
        let onScreen = buttonWindow.convertToScreen(buttonRect)
        var x = onScreen.midX - panel.frame.width / 2
        let y = onScreen.minY - panel.frame.height - 6
        if let screen = buttonWindow.screen ?? NSScreen.main {
            let maxX = screen.visibleFrame.maxX - panel.frame.width - 8
            let minX = screen.visibleFrame.minX + 8
            x = min(max(x, minX), maxX)
        }
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    // MARK: - Dismiss on outside click

    private func installClickMonitor() {
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.hidePanel()
        }
    }

    private func removeClickMonitor() {
        if let monitor = clickMonitor { NSEvent.removeMonitor(monitor); clickMonitor = nil }
    }

    // MARK: - Right-click fallback menu

    private func showContextMenu() {
        let menu = NSMenu()
        let refresh = NSMenuItem(title: "Refresh now", action: #selector(menuRefresh), keyEquivalent: "r")
        refresh.target = self
        menu.addItem(refresh)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Caelum",
                                action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        if let button = statusItem.button {
            menu.popUp(positioning: nil,
                       at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        }
    }

    @objc private func menuRefresh() { appState.refresh() }

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
