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
    /// Hook to nudge the prefetcher when the user switches source.
    var onSourceSelected: (() -> Void)?

    let scheduler = Scheduler()
    private var batch: [CosmicImage] = []
    private var index = 0
    private var loadToken = 0
    private var resolutionCache: [String: ResolutionHint] = [:]
    /// In-memory cache of crisp, downsampled hero images for instant re-display.
    private let heroCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 12
        return cache
    }()
    /// Longest edge (px) of the hero downsample — sharp on Retina, light on memory.
    private let heroMaxPixel = 1600

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

        // Stage 0 — instant crisp hero from memory (re-selecting a source, etc.).
        if let cached = heroCache.object(forKey: image.id as NSString) {
            setHero(cached)
        } else if let file = ImageCache.shared.cachedFileIfPresent(for: image),
                  let crisp = ImageCache.shared.downsampled(file, maxPixel: heroMaxPixel) {
            // Already prefetched to disk → decode a crisp downsample instantly.
            heroCache.setObject(crisp, forKey: image.id as NSString)
            setHero(crisp)
        } else {
            // Stage 1 — fast remote thumbnail for an immediate first paint.
            let quick = await Self.loadImage(image.previewURL)
            guard token == loadToken else { return }
            if let quick { setHero(quick) }
        }
        onImageReady?()
        Preferences.shared.recordFetch()

        // Stage 2 — ensure the full image is cached (instant if prefetched), then
        // upgrade to a crisp high-res hero, read the true resolution, set wallpaper.
        guard let file = try? await ImageCache.shared.localURL(for: image), token == loadToken else {
            if applyWallpaper && !image.isVideo { await applyWallpaperNow() }
            return
        }
        if let crisp = ImageCache.shared.downsampled(file, maxPixel: heroMaxPixel) {
            heroCache.setObject(crisp, forKey: image.id as NSString)
            if current?.id == image.id { setHero(crisp) }
        }
        if let dims = ImageCache.shared.pixelSize(of: file) {
            let hint = ResolutionHint.classify(width: dims.width, height: dims.height)
            resolutionCache[image.id] = hint
            if current?.id == image.id { withAnimation(Theme.Motion.snappy) { actualResolution = hint } }
        }
        if applyWallpaper && !image.isVideo { await apply(file: file, id: image.id) }
    }

    private func setHero(_ image: NSImage) {
        withAnimation(Theme.Motion.gentle) {
            heroImage = image
            if Preferences.shared.dynamicAccent {
                accent = Color(nsColor: DominantColor.accent(from: image))
            }
            phase = .ready
        }
    }

    // MARK: - Wallpaper

    /// Applies an already-cached local file as the wallpaper (no re-download).
    private func apply(file: URL, id: String) async {
        withAnimation(Theme.Motion.snappy) { isApplyingWallpaper = true }
        defer { withAnimation(Theme.Motion.snappy) { isApplyingWallpaper = false } }
        let didSet = WallpaperManager.apply(localFileURL: file,
                                            allScreens: Preferences.shared.setOnAllScreens)
        if didSet {
            withAnimation(Theme.Motion.bouncy) { wallpaperAppliedID = id }
            if Preferences.shared.chimeOnUpdate { NSSound(named: "Glass")?.play() }
        }
    }

    func applyWallpaperNow() async {
        guard let image = current, !image.isVideo else { return }
        do {
            let file = try await ImageCache.shared.localURL(for: image)
            await apply(file: file, id: image.id)
        } catch {
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
