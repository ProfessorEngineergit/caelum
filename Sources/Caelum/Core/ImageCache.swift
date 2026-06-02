import Foundation
import CryptoKit

/// Downloads remote imagery to Application Support and hands back local file
/// URLs (the wallpaper API and the ambient slideshow both need on-disk files).
/// Deduplicates by content URL and prunes to a bounded number of files.
final class ImageCache {
    static let shared = ImageCache()

    let directory: URL
    private let maxFiles = 80

    init() {
        let base = FileManager.default.urls(for: .applicationSupportDirectory,
                                            in: .userDomainMask).first!
        directory = base.appendingPathComponent("Caelum/Cache", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory,
                                                 withIntermediateDirectories: true)
    }

    /// Returns a local file URL for the image, downloading it if not cached.
    func localURL(for image: CosmicImage) async throws -> URL {
        let file = directory.appendingPathComponent(filename(for: image.imageURL))
        if FileManager.default.fileExists(atPath: file.path) {
            touch(file)
            return file
        }
        let data = try await HTTPClient.data(from: image.imageURL)
        guard data.count > 1024 else { throw SourceError.noImage }
        try data.write(to: file, options: .atomic)
        prune()
        return file
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
