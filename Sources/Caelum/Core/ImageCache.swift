import Foundation
import CryptoKit
import ImageIO

/// Downloads remote imagery to Application Support and hands back local file
/// URLs (the wallpaper API and the ambient slideshow both need on-disk files).
/// Deduplicates by content URL and prunes to a bounded number of files.
final class ImageCache {
    static let shared = ImageCache()

    let directory: URL
    private let maxFiles = 80
    /// APOD (and others) occasionally serve gigapixel images hundreds of MB in
    /// size. Above this cap we fall back to the smaller variant for wallpaper.
    private let maxWallpaperBytes: Int64 = 45_000_000

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        directory = base.appendingPathComponent("Caelum/Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
    }

    /// Returns a local file URL for the image, downloading it if not cached.
    /// Tries the chosen (HD) URL first; if that fails (e.g. a 403 on the ~orig
    /// asset) it falls back to the thumbnail so a source is never broken.
    func localURL(for image: CosmicImage) async throws -> URL {
        let primary = await wallpaperURL(for: image)
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

    private func cachedFile(for url: URL) -> URL? {
        let file = directory.appendingPathComponent(filename(for: url))
        guard FileManager.default.fileExists(atPath: file.path) else { return nil }
        touch(file)
        return file
    }

    private func download(_ url: URL) async throws -> URL {
        let data = try await HTTPClient.data(from: url)
        guard data.count > 1024 else { throw SourceError.noImage }
        let file = directory.appendingPathComponent(filename(for: url))
        try data.write(to: file, options: .atomic)
        prune()
        return file
    }

    /// Pick the HD image unless it exceeds the cap, in which case use the
    /// (smaller) thumbnail variant. One lightweight HEAD request.
    private func wallpaperURL(for image: CosmicImage) async -> URL {
        guard let thumb = image.thumbURL, thumb != image.imageURL else { return image.imageURL }
        if let size = await contentLength(image.imageURL), size > maxWallpaperBytes {
            return thumb
        }
        return image.imageURL
    }

    private func contentLength(_ url: URL) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 12
        guard let (_, response) = try? await HTTPClient.session.data(for: request) else { return nil }
        let length = response.expectedContentLength
        return length > 0 ? length : nil
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
        let names = [filename(for: image.imageURL)]
        return names.contains { FileManager.default.fileExists(atPath: directory.appendingPathComponent($0).path) }
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
