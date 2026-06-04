import AppKit

/// Drives Caelum's background behaviour:
///   • A daily refresh, triggered on launch, on wake, and via a watchdog timer.
///   • The last fetch date is persisted in UserDefaults so day changes are
///     detected correctly even after an app restart.
///   • An optional library-rotation interval.
final class Scheduler {
    var onDailyRefresh: (() -> Void)?
    var onRotate: (() -> Void)?

    private var watchdogTimer: Timer?
    private var rotateTimer: Timer?

    func start() {
        installWatchdog()
        rescheduleRotation()
        let nc = NSWorkspace.shared.notificationCenter
        nc.addObserver(self, selector: #selector(systemDidWake),
                       name: NSWorkspace.didWakeNotification, object: nil)
        // Also fire when the date changes while the app is open (e.g. running across midnight)
        NotificationCenter.default.addObserver(
            self, selector: #selector(significantTimeChange),
            name: .NSSystemClockDidChange, object: nil)
        // Initial check on first launch
        checkAndRefreshIfNeeded()
    }

    /// Re-read rotation preferences and restart that timer.
    func rescheduleRotation() {
        rotateTimer?.invalidate()
        rotateTimer = nil
        guard Preferences.shared.rotateLibrary else { return }
        let interval = TimeInterval(Preferences.shared.rotateMinutes * 60)
        rotateTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            self?.onRotate?()
        }
    }

    // MARK: - Watchdog

    /// Watchdog fires every 5 minutes — cheap date comparison that handles:
    ///   • Mac sleeping past midnight
    ///   • App relaunch after a missed day
    ///   • Normal day-boundary crossing while the app is running
    private func installWatchdog() {
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 5 * 60, repeats: true) { [weak self] _ in
            self?.checkAndRefreshIfNeeded()
        }
    }

    private func checkAndRefreshIfNeeded() {
        guard Preferences.shared.autoDailyRefresh,
              Preferences.shared.fetchNeededToday else { return }
        onDailyRefresh?()
    }

    @objc private func systemDidWake() {
        // Always check on wake — the Mac may have slept over midnight
        guard Preferences.shared.autoDailyRefresh else { return }
        onDailyRefresh?()
    }

    @objc private func significantTimeChange() {
        checkAndRefreshIfNeeded()
    }
}
