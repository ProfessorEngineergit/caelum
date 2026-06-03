import AppKit

/// Drives Caelum's background behaviour: a daily refresh (also on wake from
/// sleep and on day change), plus an optional library-rotation interval.
/// Callback-based so `AppState` stays the single source of truth.
final class Scheduler {
    var onDailyRefresh: (() -> Void)?
    var onRotate: (() -> Void)?

    private var dayTimer: Timer?
    private var rotateTimer: Timer?
    private var lastRefreshedDay = -1

    func start() {
        scheduleDayWatch()
        rescheduleRotation()
        NSWorkspace.shared.notificationCenter.addObserver(
            self, selector: #selector(systemDidWake),
            name: NSWorkspace.didWakeNotification, object: nil)
    }

    /// Re-read rotation preferences and restart that timer (call after settings change).
    func rescheduleRotation() {
        rotateTimer?.invalidate()
        rotateTimer = nil
        guard Preferences.shared.rotateLibrary else { return }
        let interval = TimeInterval(Preferences.shared.rotateMinutes * 60)
        rotateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onRotate?()
        }
    }

    // MARK: - Daily

    private func scheduleDayWatch() {
        // Check every 15 minutes whether the calendar day has rolled over.
        dayTimer = Timer.scheduledTimer(withTimeInterval: 900, repeats: true) { [weak self] _ in
            self?.checkDayChange()
        }
        checkDayChange()   // also fires the initial refresh at launch
    }

    private func checkDayChange() {
        let today = Calendar.current.ordinality(of: .day, in: .era, for: Date()) ?? 0
        guard Preferences.shared.autoDailyRefresh, today != lastRefreshedDay else { return }
        lastRefreshedDay = today
        onDailyRefresh?()
    }

    @objc private func systemDidWake() {
        guard Preferences.shared.autoDailyRefresh else { return }
        onDailyRefresh?()
    }
}
