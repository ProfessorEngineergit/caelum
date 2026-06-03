import AppKit
import SwiftUI
import IOKit.pwr_mgt

/// The in-app "screensaver": borderless full-screen windows on every display
/// running the Planetarium slideshow, dismissed on input. Keeps the display
/// awake via an IOKit power assertion while active.
@MainActor
final class AmbientController {
    private var windows: [NSWindow] = []
    private var model: AmbientModel?
    private var localMonitor: Any?
    private var globalMonitor: Any?
    private var assertionID: IOPMAssertionID = 0
    private var startedAt = Date()

    var isActive: Bool { !windows.isEmpty }

    func start() {
        guard !isActive else { return }
        Task {
            let playlist = await buildPlaylist()
            guard !playlist.isEmpty else { return }
            present(playlist)
        }
    }

    func stop() {
        guard isActive else { return }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        localMonitor = nil; globalMonitor = nil
        model?.end(); model = nil
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        if assertionID != 0 { IOPMAssertionRelease(assertionID); assertionID = 0 }
    }

    // MARK: - Playlist

    private func buildPlaylist() async -> [URL] {
        var files = ImageCache.shared.cachedFiles()
        if files.count < 4 {
            if let images = try? await SourceRegistry.active.fetchRecent(limit: 10) {
                for image in images where !image.isVideo {
                    if let file = try? await ImageCache.shared.localURL(for: image) {
                        files.append(file)
                    }
                }
            }
        }
        return Array(Set(files))
    }

    // MARK: - Presentation

    private func present(_ urls: [URL]) {
        let model = AmbientModel(urls: urls)
        self.model = model
        startedAt = Date()

        for screen in NSScreen.screens {
            let window = NSWindow(contentRect: screen.frame,
                                  styleMask: [.borderless],
                                  backing: .buffered, defer: false, screen: screen)
            window.level = .screenSaver
            window.backgroundColor = .black
            window.isOpaque = true
            window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
            window.ignoresMouseEvents = false
            window.hasShadow = false
            let hosting = NSHostingView(rootView: AmbientView(model: model))
            hosting.frame = NSRect(origin: .zero, size: screen.frame.size)
            hosting.autoresizingMask = [.width, .height]
            window.contentView = hosting
            window.setFrame(screen.frame, display: true)
            window.orderFrontRegardless()
            windows.append(window)
        }

        windows.first?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        model.begin()
        preventDisplaySleep()
        installDismissMonitors()
    }

    private func installDismissMonitors() {
        let dismiss: (NSEvent) -> Void = { [weak self] event in
            guard let self else { return }
            // Brief grace period so residual mouse movement doesn't insta-close.
            let movementOnly = (event.type == .mouseMoved)
            if movementOnly && Date().timeIntervalSince(self.startedAt) < 1.4 { return }
            self.stop()
        }
        let mask: NSEvent.EventTypeMask = [.keyDown, .leftMouseDown, .rightMouseDown,
                                           .scrollWheel, .mouseMoved]
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { event in
            dismiss(event); return event
        }
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { event in
            dismiss(event)
        }
    }

    private func preventDisplaySleep() {
        IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            "Caelum Ambient Mode" as CFString,
            &assertionID)
    }
}
