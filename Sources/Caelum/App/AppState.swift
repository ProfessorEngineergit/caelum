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
    @Published private(set) var isCurrentWallpaperReady = false
    @Published private(set) var isPreparingCurrentWallpaper = false
    @Published private(set) var wallpaperAppliedID: String?
    /// The analysed (true) resolution of the current image, once known.
    @Published private(set) var actualResolution: ResolutionHint?
    /// Gentle first-run hint shown while the cache warms (only after install/update).
    @Published private(set) var isWarmingUp = false
    /// True only during the very first APOD fetch in this process — no image yet,
    /// but we want to show a non-blocking banner rather than the full-screen spinner.
    @Published private(set) var isAPODInitializing = false

    @Published var activeSourceID: String = Preferences.shared.activeSourceID
    @Published var showExplanation = false
    @Published var showSettings = false
    @Published var showOnboarding = !Preferences.shared.hasCompletedOnboarding

    /// Hook the status-item controller installs to spin the brand glyph.
    var onImageReady: (() -> Void)?
    /// Hook to nudge the prefetcher when the user switches source.
    var onSourceSelected: (() -> Void)?
    /// Hook to warm newly fetched batches before the user clicks through them.
    var onBatchLoaded: (([CosmicImage]) -> Void)?

    let scheduler = Scheduler()
    private var batch: [CosmicImage] = []
    /// Last fetched batch per source, kept in memory so switching to a source
    /// presents instantly (its images are prefetched to disk) without a network wait.
    private var batchCache: [String: [CosmicImage]] = [:]
    private var index = 0
    private var loadToken = 0
    private var warmupTask: Task<Void, Never>?
    private var resolutionCache: [String: ResolutionHint] = [:]
    private var preparedWallpaperFiles: [String: URL] = [:]
    private var preparedFullWallpaperFiles: [String: URL] = [:]
    private var appliedWallpaperFiles: [String: URL] = [:]
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
            // The daily check runs in the background — never disrupt what's shown.
            Task { await self?.loadLatest(applyWallpaper: Preferences.shared.autoDailyRefresh, silent: true) }
        }
        scheduler.onRotate = { [weak self] in
            Task { await self?.shuffle(applyWallpaper: true) }
        }
    }

    /// Begins background scheduling and guarantees the panel has content on launch.
    /// The scheduler only triggers a load when the daily auto-refresh is actually
    /// due; on a same-day relaunch (or with auto-refresh off) it wouldn't fire, so
    /// we kick off an initial load here in that case.
    func start() {
        let schedulerWillLoad = Preferences.shared.autoDailyRefresh && Preferences.shared.fetchNeededToday
        scheduler.start()
        if !schedulerWillLoad {
            Task { await loadLatest(applyWallpaper: false) }
        }
    }

    /// Populate fixed state for an offscreen snapshot render (docs/marketing).
    func prepareSnapshot(image: CosmicImage, hero: NSImage?, accent: Color) {
        batch = [image]; index = 0
        current = image
        heroImage = hero
        self.accent = accent
        activeSourceID = image.sourceID
        wallpaperAppliedID = image.id
        isCurrentWallpaperReady = true
        isPreparingCurrentWallpaper = false
        showOnboarding = false
        phase = .ready
    }

    // MARK: - Source selection & navigation

    func selectSource(_ id: String) {
        guard id != activeSourceID else { return }
        withAnimation(Theme.Motion.snappy) { activeSourceID = id }
        Preferences.shared.activeSourceID = id
        onSourceSelected?()   // nudge the prefetcher to warm this source

        if let cached = batchCache[id], !cached.isEmpty {
            // Instant: present from the batch we already fetched (its images are
            // prefetched to disk), then quietly refresh in the background. No
            // spinner, no download wait — the wallpaper is applyable immediately.
            loadToken += 1
            let token = loadToken
            batch = cached
            index = cached.firstIndex(where: { !$0.isVideo }) ?? 0
            Task {
                await present(cached[index], applyWallpaper: false, token: token)
                await loadLatest(applyWallpaper: false, silent: true)
            }
        } else {
            Task { await loadLatest(applyWallpaper: false) }
        }
    }

    /// Hold a source's freshly fetched batch in memory (fed by the prefetcher) so a
    /// later switch to it is instant. Doesn't touch what's currently displayed.
    func cacheBatch(_ images: [CosmicImage], for id: String) {
        guard !images.isEmpty else { return }
        batchCache[id] = images
    }

    func refresh() { Task { await loadLatest(applyWallpaper: false) } }
    func shuffleNext() { Task { await shuffle(applyWallpaper: false) } }

    /// Fetch and present the source's latest image.
    /// - `silent`: a background refresh (the scheduled daily check). When content
    ///   is already on screen it never shows a spinner, never disrupts the current
    ///   image, and only swaps in genuinely new content — seamlessly. User-initiated
    ///   loads (selecting a source, tapping refresh) always pass `silent: false` so
    ///   the panel responds visibly.
    func loadLatest(applyWallpaper: Bool, silent: Bool = false) async {
        loadToken += 1
        let token = loadToken
        let isColdStart = heroImage == nil          // captured before await
        let isAPOD = activeSourceID == "apod"

        if silent && !isColdStart {
            // Background refresh with content already shown — stay completely quiet.
            withAnimation(Theme.Motion.gentle) { errorText = nil }
        } else if isAPOD && isColdStart {
            // Very first APOD load: show the non-blocking "downloading…" banner
            // instead of the full-screen spinner so the panel is usable immediately.
            withAnimation(Theme.Motion.gentle) {
                phase = .loading; errorText = nil; isAPODInitializing = true
            }
        } else {
            withAnimation(Theme.Motion.gentle) { phase = .loading; errorText = nil }
        }

        do {
            let images = try await activeSource.fetchRecent(limit: 12)
            guard token == loadToken else { return }
            guard !images.isEmpty else { throw SourceError.empty }
            batch = images
            batchCache[activeSourceID] = images
            onBatchLoaded?(images)
            index = images.firstIndex(where: { !$0.isVideo }) ?? 0
            let target = images[index]

            if silent && !isColdStart && target.id == current?.id {
                // Nothing new since last time — leave the displayed image untouched.
            } else {
                await present(target, applyWallpaper: applyWallpaper, token: token)
            }
            withAnimation(Theme.Motion.gentle) { isAPODInitializing = false }
        } catch {
            guard token == loadToken else { return }
            withAnimation(Theme.Motion.gentle) { isAPODInitializing = false }
            if silent && !isColdStart {
                // Background refresh failed — keep the current image, fail quietly.
                NSLog("Caelum: background refresh failed quietly: %@", String(describing: error))
            } else {
                NSLog("Caelum: loadLatest ERROR %@", String(describing: error))
                withAnimation(Theme.Motion.gentle) {
                    phase = .error
                    errorText = friendly(error)
                }
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
        let cachedFile = cachedWallpaperFile(for: image)
        withAnimation(Theme.Motion.snappy) {
            current = image
            actualResolution = resolutionCache[image.id]   // instant if already analysed
            isCurrentWallpaperReady = cachedFile != nil
            isPreparingCurrentWallpaper = !image.isVideo && cachedFile == nil
        }
        let previewWallpaperTask: Task<URL?, Never>? = image.isVideo || cachedFile != nil ? nil : Task.detached(priority: .userInitiated) {
            try? await ImageCache.shared.localPreviewURL(for: image)
        }
        let fullWallpaperTask: Task<URL?, Never>? = image.isVideo ? nil : Task.detached(priority: .userInitiated) {
            try? await ImageCache.shared.localURL(for: image)
        }

        // Stage 0 — instant crisp hero from memory (re-selecting a source, etc.).
        if let cached = heroCache.object(forKey: image.id as NSString) {
            setHero(cached)
        } else if let file = cachedFile,
                  let crisp = ImageCache.shared.downsampled(file, maxPixel: heroMaxPixel) {
            // Already prefetched to disk → decode a crisp downsample instantly.
            heroCache.setObject(crisp, forKey: image.id as NSString)
            setHero(crisp)
        } else {
            // Stage 1 — fast remote thumbnail for an immediate first paint.
            let previewFile = await previewWallpaperTask?.value
            var quick = previewFile.flatMap {
                ImageCache.shared.downsampled($0, maxPixel: heroMaxPixel)
            }
            if quick == nil {
                quick = await Self.loadImage(image.previewURL)
            }
            guard token == loadToken else { return }
            if let file = previewFile {
                markWallpaperReady(file, for: image, fullResolution: false)
            }
            if let quick { setHero(quick) }
        }
        onImageReady?()
        Preferences.shared.recordFetch()

        // Stage 2 — ensure the full image is cached (instant if prefetched), then
        // upgrade to a crisp high-res hero, read the true resolution, set wallpaper.
        guard let fullWallpaperTask, let file = await fullWallpaperTask.value else {
            // Both the preview and the full download failed (e.g. APOD's server is
            // unreachable). Never leave the panel stuck on the loader.
            if token == loadToken, current?.id == image.id, phase == .loading {
                withAnimation(Theme.Motion.gentle) {
                    phase = .error
                    errorText = "Couldn't reach the image server. Tap to try again."
                }
            }
            markWallpaperPreparationFinished(for: image)
            if applyWallpaper && !image.isVideo { await applyWallpaperNow() }
            return
        }
        markWallpaperReady(file, for: image, fullResolution: true)
        guard token == loadToken else { return }
        if let crisp = ImageCache.shared.downsampled(file, maxPixel: heroMaxPixel) {
            heroCache.setObject(crisp, forKey: image.id as NSString)
            if current?.id == image.id { setHero(crisp) }
        } else if current?.id == image.id, phase == .loading, let direct = NSImage(contentsOf: file) {
            // Couldn't downsample but the file is there — show it directly.
            setHero(direct)
        }
        if let dims = ImageCache.shared.pixelSize(of: file) {
            let hint = ResolutionHint.classify(width: dims.width, height: dims.height)
            resolutionCache[image.id] = hint
            if current?.id == image.id { withAnimation(Theme.Motion.snappy) { actualResolution = hint } }
        }
        // Final safety net: if nothing painted, surface an error instead of hanging.
        if token == loadToken, current?.id == image.id, phase == .loading {
            withAnimation(Theme.Motion.gentle) {
                phase = .error
                errorText = "Couldn't load this image. Tap to try again."
            }
        }
        if applyWallpaper && !image.isVideo {
            await apply(file: file, id: image.id)
        } else if wallpaperAppliedID == image.id, appliedWallpaperFiles[image.id] != file {
            await apply(file: file, id: image.id, playChime: false)
        }
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
    private func apply(file: URL, id: String, playChime: Bool = true) async {
        withAnimation(Theme.Motion.snappy) { isApplyingWallpaper = true }
        defer { withAnimation(Theme.Motion.snappy) { isApplyingWallpaper = false } }
        let shouldApplyAllScreens = Preferences.shared.setOnAllScreens
        let didSet = WallpaperManager.applyPrimary(localFileURL: file)
        if didSet {
            appliedWallpaperFiles[id] = file
            withAnimation(Theme.Motion.bouncy) { wallpaperAppliedID = id }
            if playChime && Preferences.shared.chimeOnUpdate { WallpaperChime.shared.play() }
            if shouldApplyAllScreens {
                Task.detached(priority: .utility) {
                    WallpaperManager.applySecondaryScreens(localFileURL: file)
                }
            }
        }
    }

    func applyWallpaperNow(playChime: Bool = true) async {
        guard let image = current, !image.isVideo else { return }
        if let file = cachedWallpaperFile(for: image) {
            markWallpaperReady(file, for: image, fullResolution: preparedFullWallpaperFiles[image.id] == file)
            await apply(file: file, id: image.id, playChime: playChime)
            return
        }
        do {
            let file = try await ImageCache.shared.localPreviewURL(for: image)
            markWallpaperReady(file, for: image, fullResolution: false)
            await apply(file: file, id: image.id, playChime: playChime)
            if let full = try? await ImageCache.shared.localURL(for: image), full != file {
                markWallpaperReady(full, for: image, fullResolution: true)
                await apply(file: full, id: image.id, playChime: false)
            }
        } catch {
            withAnimation { errorText = friendly(error) }
        }
    }

    func setWallpaper() { Task { await applyWallpaperNow() } }

    func completeOnboarding(apiKey: String) {
        let key = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !key.isEmpty { Preferences.shared.nasaAPIKey = key }
        Preferences.shared.hasCompletedOnboarding = true
        withAnimation(Theme.Motion.gentle) { showOnboarding = false }
    }

    // MARK: - Warm-up hint

    /// Show the "getting things ready" hint, then clear it once the cache holds a
    /// preview for roughly every source — or after a safety timeout. Called only on
    /// a cold start after a fresh install or update, so it never false-alarms.
    func beginWarmup() {
        withAnimation(Theme.Motion.gentle) { isWarmingUp = true }
        warmupTask?.cancel()
        warmupTask = Task { [weak self] in
            let deadline = Date().addingTimeInterval(75)
            while !Task.isCancelled {
                if ImageCache.shared.cachedFiles().count >= 8 || Date() > deadline { break }
                try? await Task.sleep(nanoseconds: 2_500_000_000)
            }
            self?.markWarmupComplete()
        }
    }

    func markWarmupComplete() {
        warmupTask?.cancel()
        guard isWarmingUp else { return }
        withAnimation(Theme.Motion.gentle) { isWarmingUp = false }
    }

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

    private func cachedWallpaperFile(for image: CosmicImage) -> URL? {
        if let file = preparedWallpaperFiles[image.id] {
            if FileManager.default.fileExists(atPath: file.path) { return file }
            preparedWallpaperFiles[image.id] = nil
        }
        guard let file = ImageCache.shared.cachedFileIfPresent(for: image) else { return nil }
        preparedWallpaperFiles[image.id] = file
        return file
    }

    private func markWallpaperReady(_ file: URL, for image: CosmicImage, fullResolution: Bool) {
        preparedWallpaperFiles[image.id] = file
        if fullResolution { preparedFullWallpaperFiles[image.id] = file }
        guard current?.id == image.id else { return }
        withAnimation(Theme.Motion.snappy) {
            isCurrentWallpaperReady = true
            isPreparingCurrentWallpaper = !fullResolution
        }
    }

    private func markWallpaperPreparationFinished(for image: CosmicImage) {
        guard current?.id == image.id else { return }
        withAnimation(Theme.Motion.snappy) { isPreparingCurrentWallpaper = false }
    }

    private func friendly(_ error: Error) -> String {
        (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
    }

    static func loadImage(_ url: URL) async -> NSImage? {
        guard let data = try? await HTTPClient.data(from: url) else { return nil }
        return NSImage(data: data)
    }
}
