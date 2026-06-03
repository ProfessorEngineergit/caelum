import AppKit

/// Sets the desktop wallpaper using the documented `NSWorkspace` API — one call
/// per `NSScreen` so multi-display setups all update. Operates on local files
/// (downloaded by `ImageCache`).
enum WallpaperManager {

    @discardableResult
    static func apply(localFileURL: URL, allScreens: Bool) -> Bool {
        let workspace = NSWorkspace.shared
        let options: [NSWorkspace.DesktopImageOptionKey: Any] = [
            .imageScaling: NSImageScaling.scaleProportionallyUpOrDown.rawValue,
            .allowClipping: true,
        ]
        let screens = allScreens ? NSScreen.screens : [NSScreen.main].compactMap { $0 }
        var didSet = false
        for screen in screens {
            do {
                try workspace.setDesktopImageURL(localFileURL, for: screen, options: options)
                didSet = true
            } catch {
                NSLog("Caelum: failed to set wallpaper on a screen: \(error.localizedDescription)")
            }
        }
        return didSet
    }
}
