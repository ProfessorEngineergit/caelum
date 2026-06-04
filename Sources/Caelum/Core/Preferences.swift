import Foundation

/// All persisted settings, backed by `UserDefaults`. Expanded by the settings
/// UI; sources read `nasaAPIKey` and `curatedManifestURL` from here.
final class Preferences {
    static let shared = Preferences()
    private let store = UserDefaults.standard

    private enum Key {
        static let nasaAPIKey       = "nasaAPIKey"
        static let activeSourceID   = "activeSourceID"
        static let autoDaily        = "autoDailyRefresh"
        static let rotateLibrary    = "rotateLibrary"
        static let rotateMinutes    = "rotateMinutes"
        static let ambientEnabled   = "ambientEnabled"
        static let ambientIdleSecs  = "ambientIdleSeconds"
        static let ambientInterval  = "ambientIntervalSeconds"
        static let launchAtLogin    = "launchAtLogin"
        static let chimeOnUpdate    = "chimeOnUpdate"
        static let dynamicAccent    = "dynamicAccent"
        static let setOnAllScreens  = "setOnAllScreens"
        static let lastFetchedDate  = "lastFetchedDate"
        static let hasOnboarded     = "hasCompletedOnboarding"
    }

    init() {
        store.register(defaults: [
            Key.activeSourceID:  "apod",
            Key.autoDaily:       true,
            Key.rotateLibrary:   false,
            Key.rotateMinutes:   60,
            Key.ambientEnabled:  true,
            Key.ambientIdleSecs: 300,
            Key.ambientInterval: 12,
            Key.launchAtLogin:   false,
            Key.chimeOnUpdate:   true,
            Key.dynamicAccent:   true,
            Key.setOnAllScreens: true,
        ])
    }

    /// NASA key — bundled `DEMO_KEY` unless the user supplies their own free key.
    var nasaAPIKey: String {
        get {
            let key = store.string(forKey: Key.nasaAPIKey)?.trimmingCharacters(in: .whitespaces)
            return (key?.isEmpty == false) ? key! : "DEMO_KEY"
        }
        set { store.set(newValue, forKey: Key.nasaAPIKey) }
    }
    var usingDemoKey: Bool { nasaAPIKey == "DEMO_KEY" }

    var activeSourceID: String {
        get { store.string(forKey: Key.activeSourceID) ?? "apod" }
        set { store.set(newValue, forKey: Key.activeSourceID) }
    }

    var autoDailyRefresh: Bool {
        get { store.bool(forKey: Key.autoDaily) }
        set { store.set(newValue, forKey: Key.autoDaily) }
    }
    var rotateLibrary: Bool {
        get { store.bool(forKey: Key.rotateLibrary) }
        set { store.set(newValue, forKey: Key.rotateLibrary) }
    }
    var rotateMinutes: Int {
        get { max(5, store.integer(forKey: Key.rotateMinutes)) }
        set { store.set(newValue, forKey: Key.rotateMinutes) }
    }

    var ambientEnabled: Bool {
        get { store.bool(forKey: Key.ambientEnabled) }
        set { store.set(newValue, forKey: Key.ambientEnabled) }
    }
    var ambientIdleSeconds: Int {
        get { max(20, store.integer(forKey: Key.ambientIdleSecs)) }
        set { store.set(newValue, forKey: Key.ambientIdleSecs) }
    }
    var ambientIntervalSeconds: Int {
        get { max(4, store.integer(forKey: Key.ambientInterval)) }
        set { store.set(newValue, forKey: Key.ambientInterval) }
    }

    var launchAtLogin: Bool {
        get { store.bool(forKey: Key.launchAtLogin) }
        set { store.set(newValue, forKey: Key.launchAtLogin) }
    }
    var chimeOnUpdate: Bool {
        get { store.bool(forKey: Key.chimeOnUpdate) }
        set { store.set(newValue, forKey: Key.chimeOnUpdate) }
    }
    var dynamicAccent: Bool {
        get { store.bool(forKey: Key.dynamicAccent) }
        set { store.set(newValue, forKey: Key.dynamicAccent) }
    }
    var setOnAllScreens: Bool {
        get { store.bool(forKey: Key.setOnAllScreens) }
        set { store.set(newValue, forKey: Key.setOnAllScreens) }
    }

    // MARK: - Daily watchdog

    /// The date Caelum last successfully fetched and applied a new image,
    /// persisted in UserDefaults so the check survives app restarts.
    var lastFetchedDate: Date? {
        get { store.string(forKey: Key.lastFetchedDate).flatMap { CaelumDates.ymd.date(from: $0) } }
    }

    func recordFetch() {
        store.set(CaelumDates.ymd.string(from: Date()), forKey: Key.lastFetchedDate)
    }

    /// True if the last successful fetch happened on a different calendar day than today.
    var fetchNeededToday: Bool {
        guard let last = lastFetchedDate else { return true }
        return !Calendar.current.isDateInToday(last)
    }

    // MARK: - Onboarding

    var hasCompletedOnboarding: Bool {
        get { store.bool(forKey: Key.hasOnboarded) }
        set { store.set(newValue, forKey: Key.hasOnboarded) }
    }
}
