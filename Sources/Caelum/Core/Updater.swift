import AppKit

// MARK: - Versions

enum AppVersion {
    /// The running app's marketing version; `nil` when not run from a bundle (`swift run`).
    static var current: String? {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String
    }

    /// "v1.0.18" / "1.0.18" → [1, 0, 18]. Non-numeric suffixes ("1.0.18-beta") are ignored.
    static func parts(_ version: String) -> [Int] {
        var s = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("v") { s.removeFirst() }
        return s.split(separator: ".").map { Int($0.prefix(while: { $0.isNumber })) ?? 0 }
    }

    /// Strips a leading "v" — release tags are `v1.0.18`, the bundle says `1.0.18`.
    static func normalized(_ version: String) -> String {
        var s = version.trimmingCharacters(in: .whitespacesAndNewlines)
        if s.lowercased().hasPrefix("v") { s.removeFirst() }
        return s
    }

    static func isNewer(_ candidate: String, than current: String) -> Bool {
        let a = parts(candidate), b = parts(current)
        for i in 0..<max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}

/// A published GitHub release that can be installed.
struct AppRelease: Equatable {
    let version: String      // "1.0.18"
    let pageURL: URL         // the release page (manual download / release notes)
    let assetURL: URL        // Caelum.zip
    let assetSize: Int64?
}

enum UpdateError: LocalizedError {
    case noAsset
    case download(Int)
    case corrupt
    case invalidBundle(String)
    case tool(String, String)

    var errorDescription: String? {
        switch self {
        case .noAsset:               return "The release has no Caelum.zip."
        case .download(let code):    return "Download failed (HTTP \(code))."
        case .corrupt:               return "The download is incomplete."
        case .invalidBundle(let why): return "The downloaded app isn't valid (\(why))."
        case .tool(let name, let out):
            let detail = out.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty ? "\(name) failed." : "\(name) failed: \(detail)"
        }
    }
}

// MARK: - UpdateManager

/// Checks the GitHub repository's latest release for a newer Caelum, offers it in
/// the panel, and — on request or, if the user opted in, automatically — downloads
/// it, swaps the app bundle in place and relaunches.
///
/// Flow: GitHub Releases API → download `Caelum.zip` → unzip with `ditto` → verify
/// bundle id, a newer version and the code signature → hand off to a tiny shell
/// helper that waits for this process to quit, replaces the `.app` (keeping a
/// backup it restores on failure) and reopens it.
@MainActor
final class UpdateManager: ObservableObject {
    enum State: Equatable {
        case idle
        case checking
        case upToDate
        case available(AppRelease)
        case downloading(AppRelease)
        case installing(AppRelease)
        case failed(String, AppRelease?)
    }

    @Published private(set) var state: State = .idle
    /// A version the user waved away with "Later" — its banner stays hidden.
    @Published private(set) var dismissedVersion: String?
    @Published private(set) var lastChecked: Date?

    private var loop: Task<Void, Never>?
    private var installTask: Task<Void, Never>?
    private var wakeObserver: NSObjectProtocol?

    /// How often to look for a new release while Caelum runs.
    private static let checkInterval: TimeInterval = 6 * 3600

    var currentVersion: String { AppVersion.current ?? "dev" }

    /// The release currently on offer or in flight.
    var pendingRelease: AppRelease? {
        switch state {
        case .available(let r), .downloading(let r), .installing(let r): return r
        case .failed(_, let r): return r
        default: return nil
        }
    }

    /// Whether the panel should show the update banner.
    var showsBanner: Bool {
        guard let release = pendingRelease else { return false }
        switch state {
        case .available, .failed: return dismissedVersion != release.version
        default: return true      // downloading / installing are always visible
        }
    }

    // MARK: Checking

    /// Starts the background loop: a first check shortly after launch, then every
    /// 6 hours — and on wake, when the Mac slept through a scheduled check.
    func start() {
        guard loop == nil else { return }
        Task.detached { UpdateInstaller.removeWorkDirectory() }   // leftovers from a previous update
        loop = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 8 * 1_000_000_000)
            while !Task.isCancelled {
                await self?.check(userInitiated: false)
                try? await Task.sleep(nanoseconds: UInt64(Self.checkInterval * 1_000_000_000))
            }
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            // Copy the weak reference into a constant: Swift 5.10 rejects capturing
            // the closure's `self` variable in the concurrently-executing Task.
            let manager = self
            Task { @MainActor in await manager?.checkIfOverdue() }
        }
    }

    /// After wake: check only if the Mac slept through a scheduled check.
    private func checkIfOverdue() async {
        let due = lastChecked.map { Date().timeIntervalSince($0) > Self.checkInterval } ?? true
        if due { await check(userInitiated: false) }
    }

    func checkNow() { Task { await check(userInitiated: true) } }

    func check(userInitiated: Bool) async {
        switch state {
        case .checking, .downloading, .installing: return
        default: break
        }
        guard let current = AppVersion.current else {
            if userInitiated { state = .failed("Update checks only work in the installed Caelum.app.", nil) }
            return
        }
        let previous = state
        if userInitiated { state = .checking }   // background checks never flicker the UI

        do {
            let release = try await UpdateInstaller.fetchLatestRelease()
            lastChecked = Date()
            if AppVersion.isNewer(release.version, than: current) {
                state = .available(release)
                if Preferences.shared.autoInstallUpdates && UpdateInstaller.canSelfInstall {
                    install(release)
                }
            } else {
                state = .upToDate
            }
        } catch {
            NSLog("Caelum: update check failed: %@", String(describing: error))
            state = userInitiated
                ? .failed("Couldn't check for updates — \(error.localizedDescription)", nil)
                : previous
        }
    }

    func dismiss() { dismissedVersion = pendingRelease?.version }

    /// Called when the user turns on automatic installs: an update that is already
    /// on offer is installed right away instead of at the next check.
    func installPendingIfAutomatic() {
        guard Preferences.shared.autoInstallUpdates, UpdateInstaller.canSelfInstall,
              case .available(let release) = state else { return }
        install(release)
    }

    // MARK: Installing

    /// Downloads and installs `release`, then relaunches. When Caelum can't replace
    /// itself (read-only location, translocated) it opens the release page instead.
    func install(_ release: AppRelease) {
        switch state {
        case .checking, .downloading, .installing: return
        default: break
        }
        guard UpdateInstaller.canSelfInstall else {
            NSWorkspace.shared.open(release.pageURL)
            return
        }
        dismissedVersion = nil
        state = .downloading(release)
        installTask = Task { [weak self] in
            do {
                let newApp = try await UpdateInstaller.downloadAndPrepare(release)
                guard let self else { return }
                self.state = .installing(release)
                try UpdateInstaller.launchInstaller(newApp: newApp, target: Bundle.main.bundleURL)
                NSApp.terminate(nil)   // the helper takes over once we've quit
            } catch {
                NSLog("Caelum: update install failed: %@", String(describing: error))
                self?.state = .failed(error.localizedDescription, release)
            }
        }
    }
}

// MARK: - UpdateInstaller

/// The non-UI half of updating: talking to GitHub, downloading, verifying and
/// handing off to the swap-and-relaunch helper. A plain enum (no actor isolation)
/// so the blocking work runs off the main thread.
enum UpdateInstaller {
    /// True when Caelum can replace itself: it runs from a normal `.app` whose folder
    /// is writable and that macOS hasn't relocated (Gatekeeper "App Translocation").
    static var canSelfInstall: Bool {
        let bundle = Bundle.main.bundleURL
        guard bundle.pathExtension == "app",
              !bundle.path.contains("/AppTranslocation/") else { return false }
        return FileManager.default.isWritableFile(atPath: bundle.deletingLastPathComponent().path)
    }

    // MARK: - GitHub

    private struct GitHubRelease: Decodable {
        struct Asset: Decodable {
            let name: String
            let browserDownloadUrl: String
            let size: Int64?
        }
        let tagName: String
        let htmlUrl: String
        let assets: [Asset]
    }

    static let latestReleaseURL =
        URL(string: "https://api.github.com/repos/ProfessorEngineergit/caelum/releases/latest")!

    static func fetchLatestRelease() async throws -> AppRelease {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let dto = try await HTTPClient.json(GitHubRelease.self, from: latestReleaseURL, decoder: decoder)

        let asset = dto.assets.first { $0.name == "Caelum.zip" }
            ?? dto.assets.first { $0.name.lowercased().hasSuffix(".zip") }
        guard let asset,
              let assetURL = URL(string: asset.browserDownloadUrl),
              let pageURL = URL(string: dto.htmlUrl) else { throw UpdateError.noAsset }
        return AppRelease(version: AppVersion.normalized(dto.tagName),
                          pageURL: pageURL, assetURL: assetURL, assetSize: asset.size)
    }

    // MARK: - Download & verify

    static let downloadSession: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 900   // a slow connection may need a while
        return URLSession(configuration: config)
    }()

    static var workDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Caelum/Update", isDirectory: true)
    }

    static func removeWorkDirectory() {
        try? FileManager.default.removeItem(at: workDirectory)
    }

    /// Downloads the release zip, unpacks it and verifies the app inside.
    /// Returns the URL of the verified `.app`.
    static func downloadAndPrepare(_ release: AppRelease) async throws -> URL {
        let fm = FileManager.default
        let work = workDirectory
        try? fm.removeItem(at: work)
        try fm.createDirectory(at: work, withIntermediateDirectories: true)

        var request = URLRequest(url: release.assetURL)
        request.setValue(HTTPClient.userAgent, forHTTPHeaderField: "User-Agent")
        let (tmp, response) = try await downloadSession.download(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else { throw UpdateError.download(status) }

        let zip = work.appendingPathComponent("Caelum.zip")
        try fm.moveItem(at: tmp, to: zip)
        if let expected = release.assetSize, expected > 0 {
            let attrs = try fm.attributesOfItem(atPath: zip.path)
            if let size = (attrs[.size] as? NSNumber)?.int64Value, size != expected {
                throw UpdateError.corrupt
            }
        }

        let extracted = work.appendingPathComponent("extracted", isDirectory: true)
        try fm.createDirectory(at: extracted, withIntermediateDirectories: true)
        try run("/usr/bin/ditto", ["-x", "-k", zip.path, extracted.path])

        guard let app = try fm.contentsOfDirectory(at: extracted, includingPropertiesForKeys: nil)
                .first(where: { $0.pathExtension == "app" }) else {
            throw UpdateError.invalidBundle("no app in the archive")
        }

        // It must be Caelum, and newer than what's running (no update loops).
        let info = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist"))
        guard let bundleID = info?["CFBundleIdentifier"] as? String,
              bundleID == Bundle.main.bundleIdentifier else {
            throw UpdateError.invalidBundle("wrong bundle identifier")
        }
        guard let version = info?["CFBundleShortVersionString"] as? String,
              AppVersion.isNewer(version, than: AppVersion.current ?? "0") else {
            throw UpdateError.invalidBundle("not newer than this version")
        }
        // Catches truncated or tampered bundles (ad-hoc signatures verify too).
        try run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        return app
    }

    @discardableResult
    static func run(_ path: String, _ arguments: [String]) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: path)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let output = String(decoding: data, as: UTF8.self)
        guard process.terminationStatus == 0 else {
            throw UpdateError.tool(URL(fileURLWithPath: path).lastPathComponent, output)
        }
        return output
    }

    // MARK: - Swap & relaunch

    /// Runs after Caelum quits: waits for the process to exit, moves the old bundle
    /// aside, copies the new one into place (restoring the old one if that fails),
    /// drops any quarantine flag and reopens the app.
    static let installScript = #"""
    #!/bin/bash
    PID="$1"; NEW="$2"; TARGET="$3"
    BACKUP="$(dirname "$NEW")/previous.app"

    for _ in $(seq 1 100); do
      kill -0 "$PID" 2>/dev/null || break
      sleep 0.3
    done

    rm -rf "$BACKUP"
    if mv "$TARGET" "$BACKUP"; then
      if /usr/bin/ditto "$NEW" "$TARGET"; then
        /usr/bin/xattr -dr com.apple.quarantine "$TARGET" 2>/dev/null
        rm -rf "$BACKUP" "$NEW"
        echo "updated $TARGET"
      else
        echo "copy failed - restoring the previous version"
        rm -rf "$TARGET"
        mv "$BACKUP" "$TARGET"
      fi
    else
      echo "could not move the running app aside"
    fi
    /usr/bin/open "$TARGET"
    """#

    static func launchInstaller(newApp: URL, target: URL) throws {
        let fm = FileManager.default
        let work = workDirectory
        let script = work.appendingPathComponent("install.sh")
        try installScript.write(to: script, atomically: true, encoding: .utf8)
        try fm.setAttributes([.posixPermissions: 0o755], ofItemAtPath: script.path)

        let logURL = work.appendingPathComponent("install.log")
        fm.createFile(atPath: logURL.path, contents: nil)
        let log = try FileHandle(forWritingTo: logURL)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [script.path,
                             String(ProcessInfo.processInfo.processIdentifier),
                             newApp.path, target.path]
        process.standardInput = FileHandle.nullDevice
        process.standardOutput = log
        process.standardError = log
        try process.run()   // outlives this app: the child is reparented when we quit
    }
}
