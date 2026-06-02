import AppKit

// Hidden diagnostic mode — fetch from every source and exit (no GUI).
if CommandLine.arguments.contains("--smoke-test") {
    SmokeTest.run()
}

// Caelum runs as a menu-bar-only agent (LSUIElement). No Dock icon, no main
// window — just the status item and its popover.

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
