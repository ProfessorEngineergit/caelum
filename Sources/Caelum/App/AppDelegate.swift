import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusController: StatusItemController!
    private var onboarding: OnboardingController?
    private let prefetcher = Prefetcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installEditMenu()   // restores ⌘C/⌘V/⌘X/⌘A/⌘Z in text fields

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

    /// As an LSUIElement (menu-bar) app, Caelum has no menu bar — so AppKit never
    /// installs the standard Edit menu, and ⌘C/⌘V/⌘X/⌘A/⌘Z don't reach the focused
    /// text field (e.g. the NASA-key field in Settings and onboarding). Installing a
    /// minimal main menu fixes that: the menu never shows, but its key equivalents are
    /// dispatched down the responder chain to the field editor, so copy/paste work.
    private func installEditMenu() {
        let mainMenu = NSMenu()

        let appItem = NSMenuItem()
        mainMenu.addItem(appItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Caelum",
                        action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appItem.submenu = appMenu

        let editItem = NSMenuItem()
        mainMenu.addItem(editItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo",       action: Selector(("undo:")),      keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo",       action: Selector(("redo:")),      keyEquivalent: "Z")
        editMenu.addItem(.separator())
        editMenu.addItem(withTitle: "Cut",        action: Selector(("cut:")),       keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy",       action: Selector(("copy:")),      keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste",      action: Selector(("paste:")),     keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: Selector(("selectAll:")), keyEquivalent: "a")
        editItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }
}
