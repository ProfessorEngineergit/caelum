import Foundation

/// A fixed gallery of hand-picked, resolution-verified NASA assets. Used where
/// the live search is unreliable (planetary imagery). Each asset resolves to its
/// `~orig` (maximum-resolution) file, with `ImageCache` falling back to the
/// thumbnail if needed. Rotates daily for variety while staying deterministic so
/// the prefetcher caches exactly what's shown.
struct StaticGallerySource: ImageSource {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let accentHex: UInt32
    var typicalResolution: ResolutionHint { .uhd }
    let assets: [Asset]

    struct Asset {
        let title: String
        let nasaID: String
        let credit: String
        let explanation: String
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        guard !assets.isEmpty else { throw SourceError.empty }
        let offset = Int(Date().timeIntervalSince1970 / 86_400) % assets.count
        let rotated = Array(assets[offset...] + assets[..<offset])
        let images = rotated.compactMap { asset -> CosmicImage? in
            let base = "https://images-assets.nasa.gov/image/\(asset.nasaID)/\(asset.nasaID)"
            guard let imageURL = URL(string: base + "~orig.jpg") else { return nil }
            return CosmicImage(
                id: "\(id)-\(asset.nasaID)",
                title: asset.title,
                credit: asset.credit,
                explanation: asset.explanation,
                date: nil,
                sourceID: id,
                pageURL: URL(string: "https://images.nasa.gov/details/\(asset.nasaID)"),
                imageURL: imageURL,
                thumbURL: URL(string: base + "~medium.jpg"),
                isVideo: false,
                resolution: .uhd)
        }
        return Array(images.prefix(max(limit, 1)))
    }
}

extension StaticGallerySource {
    /// Solar System — verified high-resolution JPL planetary imagery.
    static let solar = StaticGallerySource(
        id: "solar", name: "Solar System", subtitle: "Planets & moons",
        symbol: "sun.max.fill", accentHex: 0xFFD166,
        assets: [
            .init(title: "The Day the Earth Smiled", nasaID: "PIA17172",
                  credit: "NASA/JPL-Caltech/SSI",
                  explanation: "Saturn backlit by the Sun in a 9,000-pixel mosaic from Cassini — Earth is a faint dot beneath the rings."),
            .init(title: "Jupiter from Juno", nasaID: "PIA22946",
                  credit: "NASA/JPL-Caltech/SwRI/MSSS",
                  explanation: "The turbulent, swirling cloud bands of Jupiter captured by NASA's Juno spacecraft."),
            .init(title: "Curiosity's Self-Portrait on Mars", nasaID: "PIA17944",
                  credit: "NASA/JPL-Caltech/MSSS",
                  explanation: "A self-portrait of the Curiosity rover assembled from dozens of MAHLI images at the foot of Mount Sharp."),
            .init(title: "Saturn", nasaID: "PIA21345",
                  credit: "NASA/JPL-Caltech/SSI",
                  explanation: "A natural-colour portrait of Saturn and its magnificent ring system from the Cassini orbiter."),
            .init(title: "In Saturn's Shadow", nasaID: "PIA08329",
                  credit: "NASA/JPL/Space Science Institute",
                  explanation: "Cassini looks back at an eclipsed Saturn, its rings glowing in scattered sunlight."),
        ])
}
