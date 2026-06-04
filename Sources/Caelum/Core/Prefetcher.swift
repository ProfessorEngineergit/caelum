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
    private let periodNanos: UInt64 = 30 * 60 * 1_000_000_000

    func start() {
        loopTask?.cancel()
        loopTask = Task.detached(priority: .utility) { [weak self] in
            guard let self else { return }
            // Small head start so the foreground initial load goes first.
            try? await Task.sleep(nanoseconds: 4 * 1_000_000_000)
            while !Task.isCancelled {
                await self.prefetchCycle()
                try? await Task.sleep(nanoseconds: self.periodNanos)
            }
        }
    }

    func stop() {
        loopTask?.cancel()
        nudgeTask?.cancel()
    }

    /// Prioritised prefetch of the active source's batch — call on source switch.
    func nudgeActive() {
        nudgeTask?.cancel()
        nudgeTask = Task.detached(priority: .utility) { [weak self] in
            await self?.prefetch(source: SourceRegistry.active, count: 6)
        }
    }

    // MARK: - Internals

    private func prefetchCycle() async {
        await prefetch(source: SourceRegistry.active, count: 6)
        for source in SourceRegistry.all where source.id != SourceRegistry.active.id {
            if Task.isCancelled { return }
            await prefetch(source: source, count: 1)
        }
    }

    private func prefetch(source: ImageSource, count: Int) async {
        guard let images = try? await source.fetchRecent(limit: count) else { return }
        for image in images where !image.isVideo {
            if Task.isCancelled { return }
            if ImageCache.shared.isCached(image) { continue }
            _ = try? await ImageCache.shared.localURL(for: image)
            // Be polite between downloads.
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }
}
