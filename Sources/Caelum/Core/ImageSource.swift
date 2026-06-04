import Foundation

/// Anything Caelum can pull cosmic imagery from. Each concrete source only has
/// to implement `fetchRecent(limit:)`; `fetchLatest`/`fetchRandom` are derived.
protocol ImageSource {
    /// Stable identifier, e.g. "apod".
    var id: String { get }
    /// Display name, e.g. "NASA APOD".
    var name: String { get }
    /// Short tagline shown under the name.
    var subtitle: String { get }
    /// SF Symbol used as the source's chip glyph.
    var symbol: String { get }
    /// Brand-ish accent used on the chip when this source isn't the active one.
    var accentHex: UInt32 { get }
    /// Whether this source uses the (bundled, user-overridable) NASA API key.
    var usesNASAKey: Bool { get }
    /// Typical resolution of images from this source (used for badge display).
    var typicalResolution: ResolutionHint { get }

    /// Most recent images, newest first.
    func fetchRecent(limit: Int) async throws -> [CosmicImage]
}

extension ImageSource {
    var usesNASAKey: Bool { false }
    var typicalResolution: ResolutionHint { .hd }

    func fetchLatest() async throws -> CosmicImage {
        guard let first = try await fetchRecent(limit: 1).first else { throw SourceError.empty }
        return first
    }

    func fetchRandom() async throws -> CosmicImage {
        let batch = try await fetchRecent(limit: 25)
        guard let pick = batch.randomElement() else { throw SourceError.empty }
        return pick
    }

    /// Prefer an image (not a video) when one is available in a small batch.
    func fetchLatestImage() async throws -> CosmicImage {
        let batch = try await fetchRecent(limit: 8)
        if let image = batch.first(where: { !$0.isVideo }) { return image }
        if let first = batch.first { return first }
        throw SourceError.empty
    }
}

enum SourceError: LocalizedError {
    case empty
    case badURL
    case http(Int)
    case decoding(String)
    case noImage

    var errorDescription: String? {
        switch self {
        case .empty:            return "The source returned no images."
        case .badURL:           return "A malformed URL was produced."
        case .http(let code):   return "Network error (HTTP \(code))."
        case .decoding(let d):  return "Could not read the response: \(d)"
        case .noImage:          return "No usable image was found."
        }
    }
}
