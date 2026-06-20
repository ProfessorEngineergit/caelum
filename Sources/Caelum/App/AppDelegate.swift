import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusController: StatusItemController!
    private let prefetcher = Prefetcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        appState = AppState()
        statusController = StatusItemController(appState: appState)

        // Background prefetcher — keep the cache warm so switches feel instant.
        appState.onSourceSelected = { [weak self] in self?.prefetcher.nudgeActive() }
        appState.onBatchLoaded = { [weak self] images in self?.prefetcher.warm(images) }
        prefetcher.start()

        // Kick off scheduling — the initial daily check loads the first image.
        appState.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        prefetcher.stop()
    }
}
