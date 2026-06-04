import SwiftUI
import AppKit

/// The single source of truth that binds the Core to the UI. Owns the current
/// image, the loaded hero preview, the dynamic accent and the scheduler.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable { case loading, ready, error }

    @Published private(set) var current: CosmicImage?
    @Published private(set) var heroImage: NSImage?
    @Published private(set) var phase: Phase = .loading
    @Published private(set) var errorText: String?
    @Published private(set) var accent: Color = Theme.Palette.auroraViolet
    @Published private(set) var isApplyingWallpaper = false
    @Published private(set) var wallpaperAppliedID: String?
    /// The analysed (true) resolution of the current image, once known.
    @Published private(set) var actualResolution: ResolutionHint?

    @Published var activeSourceID: String = Preferences.shared.activeSourceID
    @Published var showExplanation = false
    @Published var showSettings = false

    /// Hook the status-item controller installs to spin the brand glyph.
    var onImageReady: (() -> Void)?
    /// Hook to launch ambient mode (installed by AppDelegate).
    var startAmbient: (() -> Void)?
    /// Hook to nudge the prefetcher when the user switches source.
    var onSourceSelected: (() -> Void)?

    let scheduler = Scheduler()
    private var batch: [CosmicImage] = []
    private var index = 0
    private var loadToken = 0
    private var resolutionCache: [String: ResolutionHint] = [:]

    var activeSource: ImageSource { SourceRegistry.source(id: activeSourceID) }
    var sources: [ImageSource] { SourceRegistry.all }

    init() {
        scheduler.onDailyRefresh = { [weak self] in
            Task { await self?.loadLatest(applyWallpaper: Preferences.shared.autoDailyRefresh) }
        }
        scheduler.onRotate = { [weak self] in
            Task { await self?.shuffle(applyWallpaper: true) }
        }
    }

    /// Begins background scheduling; the initial daily check triggers the first load.
    func start() { scheduler.start() }

    /// Populate fixed state for an offscreen snapshot render (docs/marketing).
    func prepareSnapshot(image: CosmicImage, hero: NSImage?, accent: Color) {
        batch = [image]; index = 0
        current = image
        heroImage = hero
        self.accent = accent
        activeSourceID = image.sourceID
        wallpaperAppliedID = image.id
        phase = .ready
    }

    // MARK: - Source selection & navigation

    func selectSource(_ id: String) {
        guard id != activeSourceID else { return }
        withAnimation(Theme.Motion.snappy) { activeSourceID = id }
        Preferences.shared.activeSourceID = id
        onSourceSelected?()   // nudge the prefetcher to warm this source
        Task { await loadLatest(applyWallpaper: false) }
    }

    func refresh() { Task { await loadLatest(applyWallpaper: false) } }
    func shuffleNext() { Task { await shuffle(applyWallpaper: false) } }

    func loadLatest(applyWallpaper: Bool) async {
        loadToken += 1
        let token = loadToken
        withAnimation(Theme.Motion.gentle) { phase = .loading; errorText = nil }
        do {
            let images = try await activeSource.fetchRecent(limit: 12)
            guard token == loadToken else { return }
            guard !images.isEmpty else { throw SourceError.empty }
            batch = images
            index = images.firstIndex(where: { !$0.isVideo }) ?? 0
            await present(images[index], applyWallpaper: applyWallpaper, token: token)
        } catch {
            guard token == loadToken else { return }
            NSLog("Caelum: loadLatest ERROR %@", String(describing: error))
            withAnimation(Theme.Motion.gentle) {
                phase = .error
                errorText = friendly(error)
            }
        }
    }

    private func shuffle(applyWallpaper: Bool) async {
        guard batch.count > 1 else { await loadLatest(applyWallpaper: applyWallpaper); return }
        var next = (index + 1) % batch.count
        var hops = 0
        while batch[next].isVideo && hops < batch.count { next = (next + 1) % batch.count; hops += 1 }
        index = next
        await present(batch[index], applyWallpaper: applyWallpaper, token: loadToken)
    }

    // MARK: - Presentation

    private func present(_ image: CosmicImage, applyWallpaper: Bool, token: Int) async {
        withAnimation(Theme.Motion.snappy) {
            current = image
            actualResolution = resolutionCache[image.id]   // instant if already analysed
        }
        let loaded = await Self.loadImage(image.previewURL)
        guard token == loadToken else { return }
        withAnimation(Theme.Motion.gentle) {
            heroImage = loaded
            if Preferences.shared.dynamicAccent, let loaded {
                accent = Color(nsColor: DominantColor.accent(from: loaded))
            }
            phase = .ready
        }
        onImageReady?()
        analyzeResolution(for: image)
        // Record the successful fetch so the daily watchdog knows today's image is up-to-date.
        Preferences.shared.recordFetch()
        if applyWallpaper && !image.isVideo { await applyWallpaperNow() }
    }

    // MARK: - Resolution analysis

    /// Determines the image's true resolution by reading the cached file's pixel
    /// dimensions (downloading it if needed — which also warms the cache). APOD
    /// in particular varies wildly, so we never trust a fixed per-source hint.
    private func analyzeResolution(for image: CosmicImage) {
        if let cached = resolutionCache[image.id] {
            actualResolution = cached
            return
        }
        Task {
            guard let file = try? await ImageCache.shared.localURL(for: image),
                  let size = ImageCache.shared.pixelSize(of: file) else { return }
            let hint = ResolutionHint.classify(width: size.width, height: size.height)
            resolutionCache[image.id] = hint
            if current?.id == image.id { actualResolution = hint }
        }
    }

    // MARK: - Wallpaper

    func applyWallpaperNow() async {
        guard let image = current, !image.isVideo else { return }
        withAnimation(Theme.Motion.snappy) { isApplyingWallpaper = true }
        defer { withAnimation(Theme.Motion.snappy) { isApplyingWallpaper = false } }
        do {
            let file = try await ImageCache.shared.localURL(for: image)
            let didSet = WallpaperManager.apply(localFileURL: file,
                                                allScreens: Preferences.shared.setOnAllScreens)
            if didSet {
                withAnimation(Theme.Motion.bouncy) { wallpaperAppliedID = image.id }
                if Preferences.shared.chimeOnUpdate { NSSound(named: "Glass")?.play() }
            }
        } catch {
            NSLog("Caelum: applyWallpaper ERROR %@", String(describing: error))
            withAnimation { errorText = friendly(error) }
        }
    }

    func setWallpaper() { Task { await applyWallpaperNow() } }

    /// Save the full-resolution image to ~/Downloads.
    func saveToDownloads() {
        guard let image = current else { return }
        Task {
            guard let file = try? await ImageCache.shared.localURL(for: image) else { return }
            let downloads = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
            let name = "Caelum-\(image.sourceID)-\(image.id.suffix(8)).\(file.pathExtension)"
            let destination = downloads.appendingPathComponent(name)
            try? FileManager.default.copyItem(at: file, to: destination)
            NSWorkspace.shared.activateFileViewerSelecting([destination])
        }
    }

    func openSourcePage() {
        if let url = current?.pageURL { NSWorkspace.shared.open(url) }
    }

    // MARK: - Helpers

    private func friendly(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    static func loadImage(_ url: URL) async -> NSImage? {
        guard let data = try? await HTTPClient.data(from: url) else { return nil }
        return NSImage(data: data)
    }
}
