import AppKit

// Caelum runs as a menu-bar-only agent (LSUIElement). No Dock icon, no main
// window — just the status item and its popover.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
