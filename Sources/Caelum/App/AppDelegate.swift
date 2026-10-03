import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var appState: AppState!
    private var statusController: StatusItemController!
    private var intro: IntroController?
    private let prefetcher = Prefetcher()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        installEditMenu()   // restores ⌘C/⌘V/⌘X/⌘A/⌘Z in text fields

        appState = AppState()
        appState.showOnboarding = false   // handled full-screen, not in the panel
        statusController = StatusItemController(appState: appState)

        // Background prefetcher — caches every source's batch so switches, shuffles
        // and applying a wallpaper are instant.
        appState.onSourceSelected = { [weak self] in self?.prefetcher.nudgeActive() }
        appState.onBatchLoaded = { [weak self] images in self?.prefetcher.warm(images) }
        // Each prefetched batch list is held in memory so switching to a source
        // doesn't even wait for a network fetch.
        prefetcher.onBatchFetched = { [weak appState] id, images in
            let state = appState
            Task { @MainActor in state?.cacheBatch(images, for: id) }
        }
        // First-run caching progress → drives the "preparing your library" UI.
        prefetcher.onSetupProgress = { [weak appState] p in
            let state = appState
            Task { @MainActor in state?.reportSetupProgress(p) }
        }
        prefetcher.start()

        // Gentle "getting things ready" hint — only on a genuinely cold start after a
        // fresh install or update (and only if the cache is actually cold), so it
        // never false-alarms on a normal relaunch. Auto-fades once warm.
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
        let previousVersion = Preferences.shared.lastRunVersion
        let installedOrUpdated = previousVersion != currentVersion
        Preferences.shared.lastRunVersion = currentVersion

        // Up to 1.0.17 APOD read NASA's retired API, which now hands out a NASA logo
        // as "today's picture" — and may have set it as the wallpaper. Coming from
        // such a version, redo today's daily refresh so the real APOD replaces it.
        if let previousVersion, AppVersion.isNewer("1.0.18", than: previousVersion) {
            Preferences.shared.clearLastFetch()
        }
        if installedOrUpdated, ImageCache.shared.cachedFiles().count < 6 {
            appState.beginWarmup()
        }

        // First run (or a new intro) → the intro: apps hide, the desktop jumps to
        // hyperspace and lands in the setup; the wallpaper loads behind it.
        // After an update → the same jump lands on the update screen.
        statusController.onReplayIntro = { [weak self] in self?.showIntro() }
        statusController.onWhatsNew = { [weak self] in
            guard let current = currentVersion.map(AppVersion.normalized) else { return }
            // The release before this one: same major.minor, patch − 1.
            var parts = AppVersion.parts(current)
            if let last = parts.indices.last, parts[last] > 0 { parts[last] -= 1 }
            self?.showIntro(update: (from: parts.map(String.init).joined(separator: "."), to: current))
        }
        if !Preferences.shared.hasCompletedOnboarding
            || Preferences.shared.introSeen < IntroController.introVersion {
            showIntro()
        } else if let previousVersion, let currentVersion, previousVersion != currentVersion {
            showIntro(update: (from: AppVersion.normalized(previousVersion), to: AppVersion.normalized(currentVersion)))
        }

        // Kick off scheduling — the initial daily check loads the first image.
        appState.start()

        // macOS keeps a wallpaper per Space — carry Caelum's to each Space as it's shown.
        WallpaperManager.startSyncingSpaces()
        Task.detached(priority: .utility) { WallpaperManager.syncActiveSpace() }

        // Look for a newer release on GitHub shortly after launch and every few hours.
        appState.updater.start()
    }

    private func showIntro(update: (from: String, to: String)? = nil) {
        guard intro == nil else { return }
        let intro = IntroController(appState: appState, mode: update == nil ? .intro : .update,
                                    update: update, onFinish: { [weak self] in
            if update == nil {
                self?.appState.completeOnboarding()
                Preferences.shared.introSeen = IntroController.introVersion
            }
            self?.intro = nil
        })
        self.intro = intro
        intro.present()
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
