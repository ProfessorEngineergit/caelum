import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusController: StatusItemController!
    private var onboarding: OnboardingController?
    private let prefetcher = Prefetcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        appState = AppState()
        appState.showOnboarding = false   // handled full-screen, not in the panel
        statusController = StatusItemController(appState: appState)

        // Background prefetcher — keep the cache warm so switches feel instant.
        appState.onSourceSelected = { [weak self] in self?.prefetcher.nudgeActive() }
        appState.onBatchLoaded = { [weak self] images in self?.prefetcher.warm(images) }
        prefetcher.start()

        // First run → cinematic full-screen onboarding (over everything).
        // The wallpaper loads behind it so it's ready when the user enters.
        if !Preferences.shared.hasCompletedOnboarding {
            let onboarding = OnboardingController(onFinish: { [weak self] apiKey in
                self?.appState.completeOnboarding(apiKey: apiKey)
            })
            self.onboarding = onboarding
            onboarding.present()
        }

        // Kick off scheduling — the initial daily check loads the first image.
        appState.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        prefetcher.stop()
    }
}
