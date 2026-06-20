import Foundation
import CryptoKit
import ImageIO
import AppKit

/// Downloads remote imagery to Application Support and hands back local file
/// URLs (the wallpaper API and the ambient slideshow both need on-disk files).
/// Deduplicates by content URL and prunes to a bounded number of files.
final class ImageCache {
    static let shared = ImageCache()

    let directory: URL
    private let maxFiles = 150   // headroom so background prefetch doesn't thrash the cache
    private let inFlightLock = NSLock()
    private var inFlightDownloads: [String: Task<URL, Error>] = [:]

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        directory = base.appendingPathComponent("Caelum/Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
    }

    /// Returns a local file URL for the image, downloading it if not cached.
    /// Goes straight for the maximum-resolution asset (no pre-flight HEAD — that
    /// added a full round-trip to every load); if it fails (e.g. a 403 on the
    /// ~orig asset) it falls back to the thumbnail so a source is never broken.
    func localURL(for image: CosmicImage) async throws -> URL {
        let primary = image.imageURL
        if let file = cachedFile(for: primary) { return file }

        do {
            return try await download(primary)
        } catch {
            // Fall back to the (always-valid) thumbnail variant.
            if let thumb = image.thumbURL, thumb != primary {
                if let file = cachedFile(for: thumb) { return file }
                return try await download(thumb)
            }
            throw error
        }
    }

    /// Returns a small local image quickly, suitable for immediate preview or
    /// first-pass wallpaper application while the full-resolution file warms.
    func localPreviewURL(for image: CosmicImage) async throws -> URL {
        guard let preview = image.thumbURL else { return try await localURL(for: image) }
        if let file = cachedFile(for: preview) { return file }
        return try await download(preview)
    }

    private func cachedFile(for url: URL) -> URL? {
        let file = directory.appendingPathComponent(filename(for: url))
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        touch(file)
        return file
    }

    private func download(_ url: URL) async throws -> URL {
        let key = url.absoluteString
        let (task, isOwner) = inFlightDownload(for: key) {
            Task<URL, Error> { [self] in
                try await performDownload(url)
            }
        }

        defer {
            if isOwner { clearInFlightDownload(for: key) }
        }
        return try await task.value
    }

    private func inFlightDownload(
        for key: String,
        create: () -> Task<URL, Error>
    ) -> (task: Task<URL, Error>, isOwner: Bool) {
        inFlightLock.lock()
        defer { inFlightLock.unlock() }

        if let existing = inFlightDownloads[key] {
            return (existing, false)
        }

        let task = create()
        inFlightDownloads[key] = task
        return (task, true)
    }

    private func performDownload(_ url: URL) async throws -> URL {
        let data = try await HTTPClient.data(from: url)
        guard data.count > 1024 else { throw SourceError.noImage }
        let file = directory.appendingPathComponent(filename(for: url))
        try data.write(to: file, options: .atomic)
        prune()
        return file
    }

    private func clearInFlightDownload(for key: String) {
        inFlightLock.lock()
        inFlightDownloads[key] = nil
        inFlightLock.unlock()
    }

    /// Returns the cached local file for an image if it's already on disk
    /// (checks both the HD and thumbnail variants), without downloading.
    func cachedFileIfPresent(for image: CosmicImage) -> URL? {
        for url in [image.imageURL, image.thumbURL].compactMap({ $0 }) {
            let file = directory.appendingPathComponent(filename(for: url))
            if FileManager.default.fileExists(atPath: file.path) { touch(file); return file }
        }
        return nil
    }

    /// Decodes a crisp, memory-light downsample of an image straight to a target
    /// pixel size — sharp on Retina even from a gigapixel original, without
    /// loading the whole thing into memory. Used for the hero preview.
    func downsampled(_ fileURL: URL, maxPixel: Int) -> NSImage? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
    }

    /// Reads true pixel dimensions of an image file without decoding it
    /// (CGImageSource reads only the header). Cheap enough to call freely.
    func pixelSize(of fileURL: URL) -> (width: Int, height: Int)? {
        guard let source = CGImageSourceCreateWithURL(fileURL as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? Int,
              let h = props[kCGImagePropertyPixelHeight] as? Int else { return nil }
        return (w, h)
    }

    /// Whether the image is already on disk (no download needed).
    func isCached(_ image: CosmicImage) -> Bool {
        cachedFileIfPresent(for: image) != nil
    }

    /// Whether the full source image is already on disk. Prefetching uses this
    /// so a cached thumbnail does not block the full-resolution warmup.
    func isFullSizeCached(_ image: CosmicImage) -> Bool {
        cachedFile(for: image.imageURL) != nil
    }

    /// Local files currently in the cache, newest first.
    func cachedFiles() -> [URL] {
        let keys: [URLResourceKey] = [.contentModificationDateKey]
        let files = (try? FileManager.default.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: keys)) ?? []
        return files
            .filter { ["jpg", "jpeg", "png", "heic"].contains($0.pathExtension.lowercased()) }
            .sorted { modDate($0) > modDate($1) }
    }

    // MARK: - Internals

    private func filename(for url: URL) -> String {
        let digest = SHA256.hash(data: Data(url.absoluteString.utf8))
        let hex = digest.compactMap { String(format: "%02x", $0) }.joined()
        var ext = url.pathExtension.lowercased()
        if !["jpg", "jpeg", "png", "heic"].contains(ext) { ext = "jpg" }
        return "\(hex).\(ext)"
    }

    private func modDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
            .contentModificationDate ?? .distantPast
    }

    private func touch(_ url: URL) {
        try? FileManager.default.setAttributes([.modificationDate: Date()],
                                               ofItemAtPath: url.path)
    }

    private func prune() {
        let files = cachedFiles()
        guard files.count > maxFiles else { return }
        for file in files.dropFirst(maxFiles) {
            try? FileManager.default.removeItem(at: file)
        }
    }
}
