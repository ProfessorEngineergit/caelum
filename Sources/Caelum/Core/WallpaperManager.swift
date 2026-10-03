import AppKit

/// Sets the desktop wallpaper using the documented `NSWorkspace` API — one call
/// per `NSScreen` so multi-display setups all update. Operates on local files
/// (downloaded by `ImageCache`).
///
/// macOS keeps a wallpaper per Space, and `setDesktopImageURL` only changes the
/// active one — there is no public API for "all Spaces". So Caelum remembers the
/// last wallpaper it set and re-applies it whenever another Space becomes active
/// (`syncActiveSpace`), unless the user turned "Same wallpaper on every desktop" off.
enum WallpaperManager {

    // MARK: - Every Space

    /// Starts following Space switches and display changes. Call once at launch.
    static func startSyncingSpaces() {
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification, object: nil, queue: .main
        ) { _ in
            Task.detached(priority: .utility) { WallpaperManager.syncActiveSpace() }
        }
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { _ in
            Task.detached(priority: .utility) { WallpaperManager.syncActiveSpace() }
        }
    }

    /// Gives the now-active Space Caelum's wallpaper if it still shows another one.
    static func syncActiveSpace() {
        let prefs = Preferences.shared
        guard prefs.sameWallpaperOnAllSpaces,
              let path = prefs.appliedWallpaperPath,
              FileManager.default.fileExists(atPath: path) else { return }
        let file = URL(fileURLWithPath: path)
        let screens = prefs.setOnAllScreens ? NSScreen.screens : [NSScreen.main].compactMap { $0 }
        for screen in screens
        where NSWorkspace.shared.desktopImageURL(for: screen)?.standardizedFileURL != file.standardizedFileURL {
            _ = apply(localFileURL: file, to: screen)
        }
    }

    /// Copies a cached image to a folder of its own, so the wallpaper — which other
    /// Spaces keep pointing at — survives the image cache being pruned. Keeps the
    /// last few; returns the original file if copying fails.
    static func stage(_ file: URL) -> URL {
        let fm = FileManager.default
        let directory = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Caelum/Wallpaper", isDirectory: true)
        let target = directory.appendingPathComponent(file.lastPathComponent)   // cache names are per-image hashes
        do {
            try fm.createDirectory(at: directory, withIntermediateDirectories: true)
            if !fm.fileExists(atPath: target.path) { try fm.copyItem(at: file, to: target) }
            try? fm.setAttributes([.modificationDate: Date()], ofItemAtPath: target.path)
        } catch {
            NSLog("Caelum: couldn't stage the wallpaper: \(error.localizedDescription)")
            return file
        }
        let staged = ((try? fm.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.contentModificationDateKey])) ?? [])
            .sorted { modificationDate($0) > modificationDate($1) }
        for old in staged.dropFirst(3) where old != target { try? fm.removeItem(at: old) }
        return target
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate ?? .distantPast
    }

    // MARK: - Applying

    @discardableResult
    static func apply(localFileURL: URL, allScreens: Bool) -> Bool {
        if allScreens {
            let didSetPrimary = applyPrimary(localFileURL: localFileURL)
            applySecondaryScreens(localFileURL: localFileURL)
            return didSetPrimary
        }

        return applyPrimary(localFileURL: localFileURL)
    }

    @discardableResult
    static func applyPrimary(localFileURL: URL) -> Bool {
        guard let screen = NSScreen.main else { return false }
        let didSet = apply(localFileURL: localFileURL, to: screen)
        if didSet { Preferences.shared.appliedWallpaperPath = localFileURL.path }
        return didSet
    }

    static func applySecondaryScreens(localFileURL: URL) {
        guard let main = NSScreen.main else { return }
        for screen in NSScreen.screens where screen !== main {
            _ = apply(localFileURL: localFileURL, to: screen)
        }
    }

    @discardableResult
    private static func apply(localFileURL: URL, to screen: NSScreen) -> Bool {
        let workspace = NSWorkspace.shared
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        do {
            try workspace.setDesktopImageURL(localFileURL, for: screen, options: options)
            return true
        } catch {
            NSLog("Caelum: failed to set wallpaper on a screen: \(error.localizedDescription)")
            return false
        }
    }
}
