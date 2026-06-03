import AppKit
import CoreGraphics

/// Polls system input idle time and fires once when the configured threshold is
/// crossed (re-arms after the user returns). Drives the ambient "screensaver".
final class IdleMonitor {
    private let onIdle: () -> Void
    private var timer: Timer?
    private var hasFired = false

    /// Event types whose most-recent timestamp defines "activity".
    private let inputTypes: [CGEventType] = [
        .mouseMoved, .leftMouseDown, .rightMouseDown, .leftMouseDragged,
        .rightMouseDragged, .keyDown, .scrollWheel, .flagsChanged,
    ]

    init(onIdle: @escaping () -> Void) { self.onIdle = onIdle }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.tick()
        }
    }

    func stop() { timer?.invalidate(); timer = nil }

    private func tick() {
        let idle = inputTypes
            .map { CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: $0) }
            .min() ?? 0
        let threshold = TimeInterval(Preferences.shared.ambientIdleSeconds)
        if idle >= threshold {
            if !hasFired { hasFired = true; onIdle() }
        } else {
            hasFired = false
        }
    }
}
