import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusController: StatusItemController!
    private var ambientController: AmbientController!
    private var idleMonitor: IdleMonitor!

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        appState = AppState()
        statusController = StatusItemController(appState: appState)

        // Ambient ("screensaver") mode — manual trigger + idle auto-start.
        ambientController = AmbientController()
        appState.startAmbient = { [weak self] in self?.ambientController.start() }

        idleMonitor = IdleMonitor { [weak self] in
            guard Preferences.shared.ambientEnabled else { return }
            self?.ambientController.start()
        }
        idleMonitor.start()

        // Kick off scheduling — the initial daily check loads the first image.
        appState.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        idleMonitor?.stop()
    }
}
