import AppKit

/// Sets the desktop wallpaper using the documented `NSWorkspace` API — one call
/// per `NSScreen` so multi-display setups all update. Operates on local files
/// (downloaded by `ImageCache`).
enum WallpaperManager {

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
        return apply(localFileURL: localFileURL, to: screen)
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
