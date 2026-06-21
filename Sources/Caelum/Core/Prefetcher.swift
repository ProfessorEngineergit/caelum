import Foundation

/// Keeps the image cache warm in the background so switching sources, shuffling
/// and applying a wallpaper feel instant instead of waiting on (often slow)
/// servers.
///
/// Strategy: cache **everything**. Each cycle fetches every source's whole batch
/// and downloads a preview for every image first (small + fast → every image is
/// instantly applyable, never stuck "preparing"), then upgrades the whole library
/// to full resolution. The active source goes first. Repeats every 30 minutes,
/// runs at utility priority, yields politely, and skips anything already cached.
final class Prefetcher {
    private var loopTask: Task<Void, Never>?
    private var nudgeTask: Task<Void, Never>?
    private var batchTask: Task<Void, Never>?
    private let periodNanos: UInt64 = 30 * 60 * 1_000_000_000

    /// Called (off the main actor) with each source's freshly fetched batch list,
    /// so the app can hold it in memory and switch sources without a network wait.
    var onBatchFetched: (@Sendable (String, [CosmicImage]) -> Void)?

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

    /// Prioritised full-res warm of the active source — call on source switch.
    func nudgeActive() {
        nudgeTask?.cancel()
        let source = SourceRegistry.active
        nudgeTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let images = try? await source.fetchRecent(limit: 12) else { return }
            self?.onBatchFetched?(source.id, images)
            await self?.cache(images, fullRes: true, sleepNanos: 50_000_000)
        }
    }

    /// Warm a just-fetched batch immediately at full resolution so shuffling
    /// through it (and applying any of it) is instant.
    func warm(_ images: [CosmicImage]) {
        batchTask?.cancel()
        batchTask = Task.detached(priority: .userInitiated) { [weak self] in
            await self?.cache(images, fullRes: true, sleepNanos: 50_000_000)
        }
    }

    // MARK: - Internals

    private func prefetchCycle() async {
        let ordered = [SourceRegistry.active]
            + SourceRegistry.all.filter { $0.id != SourceRegistry.active.id }
        var fetched: [[CosmicImage]] = []

        // Pass 1 — a preview for EVERY image of EVERY source. Previews are small
        // and quick, and a cached preview is enough to apply instantly, so after
        // this pass nothing the user clicks ever sits in "preparing wallpaper".
        for source in ordered {
            if Task.isCancelled { return }
            guard let images = try? await source.fetchRecent(limit: 12) else { continue }
            onBatchFetched?(source.id, images)
            fetched.append(images)
            await cache(images, fullRes: false, sleepNanos: 40_000_000)
        }

        // Pass 2 — upgrade the whole cached library to full resolution. Reuses the
        // batches fetched in pass 1 (no second network round-trip per source).
        for images in fetched {
            if Task.isCancelled { return }
            await cache(images, fullRes: true, sleepNanos: 80_000_000)
        }
    }

    /// Download previews (and optionally full-res) for a batch, skipping anything
    /// already on disk and only pausing when an actual download happened.
    private func cache(_ images: [CosmicImage], fullRes: Bool, sleepNanos: UInt64) async {
        for image in images where !image.isVideo {
            if Task.isCancelled { return }
            var didDownload = false
            if !ImageCache.shared.isCached(image) {
                _ = try? await ImageCache.shared.localPreviewURL(for: image)
                didDownload = true
            }
            if fullRes, !ImageCache.shared.isFullSizeCached(image) {
                _ = try? await ImageCache.shared.localURL(for: image)
                didDownload = true
            }
            if didDownload { try? await Task.sleep(nanoseconds: sleepNanos) }
        }
    }
}
