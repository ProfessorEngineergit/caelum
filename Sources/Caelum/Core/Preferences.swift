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
            Key.launchAtLogin:   false,
            Key.chimeOnUpdate:   true,
            Key.dynamicAccent:   true,
            Key.setOnAllScreens: true,
        ])
    }

    /// NASA key — bundled `DEMO_KEY` unless the user supplies their own free key.
    var nasaAPIKey: String {
        get {
            guard let raw = store.string(forKey: Key.nasaAPIKey) else { return "DEMO_KEY" }
            guard let key = Self.cleanNASAKey(raw) else {
                store.removeObject(forKey: Key.nasaAPIKey)
                return "DEMO_KEY"
            }
            return key
        }
        set {
            if let key = Self.cleanNASAKey(newValue) {
                store.set(key, forKey: Key.nasaAPIKey)
            } else {
                store.removeObject(forKey: Key.nasaAPIKey)
            }
        }
    }
    var usingDemoKey: Bool { nasaAPIKey == "DEMO_KEY" }

    private static func cleanNASAKey(_ value: String) -> String? {
        let key = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !key.isEmpty, key.count <= 128 else { return nil }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "._-"))
        guard key.unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return nil }
        return key
    }

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
