import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = BrandGlyph.statusImage()
        let menu = NSMenu()
        menu.addItem(withTitle: "Quit Caelum",
                     action: #selector(NSApplication.terminate(_:)),
                     keyEquivalent: "q")
        item.menu = menu
        statusItem = item
    }
}
