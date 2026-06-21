import Foundation

/// Keeps the image cache warm in the background so switching sources and the
/// daily update feel instant instead of waiting on (often slow) servers.
///
/// Strategy: download the active source's recent batch (fast shuffle), then the
/// latest image of every other source (fast source switching), then repeat
/// every 30 minutes. Runs at utility priority and yields politely between
/// downloads. Skips anything already cached.
final class Prefetcher {
    private var loopTask: Task<Void, Never>?
    private var nudgeTask: Task<Void, Never>?
    private var batchTask: Task<Void, Never>?
    private let periodNanos: UInt64 = 30 * 60 * 1_000_000_000

    func start() {
        loopTask?.cancel()
        loopTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            // Small head start so the foreground initial load goes first.
            try? await Task.sleep(nanoseconds: 1 * 1_000_000_000)
            while !Task.isCancelled {
                await self.prefetchCycle()
                try? await Task.sleep(nanoseconds: self.periodNanos)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        nudgeTask?.cancel()
        batchTask?.cancel()
    }

    /// Prioritised prefetch of the active source's batch — call on source switch.
    func nudgeActive() {
        nudgeTask?.cancel()
        nudgeTask = Task.detached(priority: .utility) { [weak self] in
            await self?.prefetch(source: SourceRegistry.active, count: 8, fullRes: true)
        }
    }

    /// Warm a just-fetched batch immediately. Full-res for the first few (instant
    /// shuffle); the rest warm on the next cycle so we don't flood the network.
    func warm(_ images: [CosmicImage]) {
        batchTask?.cancel()
        batchTask = Task.detached(priority: .utility) { [weak self] in
            await self?.prefetch(images: Array(images.prefix(8)), fullRes: true)
        }
    }

    // MARK: - Internals

    private func prefetchCycle() async {
        // First pass — make EVERY source instantly clickable. The active source
        // gets depth (several full-res images → instant shuffle); every other
        // source gets its *latest* image at full resolution, so switching to it
        // shows a crisp wallpaper with no download wait. This is the "download
        // everything on first start" behaviour.
        await prefetch(source: SourceRegistry.active, count: 6, fullRes: true)
        for source in SourceRegistry.all where source.id != SourceRegistry.active.id {
            if Task.isCancelled { return }
            await prefetch(source: source, count: 1, fullRes: true)
        }
        // Second pass — shuffle depth for the rest, previews only so we don't
        // saturate the link with full-res for images that may never be viewed.
        for source in SourceRegistry.all where source.id != SourceRegistry.active.id {
            if Task.isCancelled { return }
            await prefetch(source: source, count: 4, fullRes: false)
        }
    }

    private func prefetch(source: ImageSource, count: Int, fullRes: Bool) async {
        guard let images = try? await source.fetchRecent(limit: count) else { return }
        await prefetch(images: images, fullRes: fullRes)
    }

    private func prefetch(images: [CosmicImage], fullRes: Bool) async {
        for image in images where !image.isVideo {
            if Task.isCancelled { return }
            if !ImageCache.shared.isCached(image) {
                _ = try? await ImageCache.shared.localPreviewURL(for: image)
            }
            if fullRes, !ImageCache.shared.isFullSizeCached(image) {
                _ = try? await ImageCache.shared.localURL(for: image)
            }
            // Be polite between downloads.
            try? await Task.sleep(nanoseconds: 150_000_000)
        }
    }
}
