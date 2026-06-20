import AppKit

// Hidden diagnostic mode — fetch from every source and exit (no GUI).
if CommandLine.arguments.contains("--smoke-test") {
    SmokeTest.run()
}

// Offscreen snapshot render for docs/marketing (no GUI run loop needed).
if let i = CommandLine.arguments.firstIndex(of: "--render-popover"),
   i + 1 < CommandLine.arguments.count {
    let out = CommandLine.arguments[i + 1]
    let hero = (i + 2 < CommandLine.arguments.count && !CommandLine.arguments[i + 2].hasPrefix("--"))
        ? CommandLine.arguments[i + 2] : nil
    let settings = CommandLine.arguments.contains("--settings")
    let welcome = CommandLine.arguments.contains("--welcome")
    MainActor.assumeIsolated {
        SnapshotRenderer.run(outPath: out, heroPath: hero, settings: settings, welcome: welcome)
    }
}

// Dev override: --source <id> selects the active source at launch.
if let i = CommandLine.arguments.firstIndex(of: "--source"),
   i + 1 < CommandLine.arguments.count {
    Preferences.shared.activeSourceID = CommandLine.arguments[i + 1]
}

// Caelum runs as a menu-bar-only agent (LSUIElement). No Dock icon, no main
// window — just the status item and its popover. Top-level code already runs
// on the main thread; assume the isolation so we can build main-actor types.
MainActor.assumeIsolated {
    let app = NSApplication.shared
    let delegate = AppDelegate()
    app.delegate = delegate
    app.setActivationPolicy(.accessory)
    app.run()
}
