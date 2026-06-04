import Foundation

/// A themed source backed by the NASA Image & Video Library search API. Rotates
/// through a set of curated queries and upgrades every result to the reliably
/// high-resolution `~orig` asset (the `~large` variant 403s for many items).
/// The original preview stays as the thumbnail, and `ImageCache` falls back to
/// it if the `~orig` download ever fails — so a cell is never broken.
struct NASASearchSource: ImageSource {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let accentHex: UInt32
    let queries: [String]
    var typicalResolution: ResolutionHint { .uhd }

    private struct Response: Decodable {
        struct Collection: Decodable { let items: [Item] }
        struct Item: Decodable { let data: [Meta]; let links: [Link]? }
        struct Meta: Decodable {
            let title: String?
            let description: String?
            let nasa_id: String?
            let date_created: String?
        }
        struct Link: Decodable { let href: String? }
        let collection: Collection
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let query = queries.randomElement() ?? queries.first ?? "nebula"
        var components = URLComponents(string: "https://images-api.nasa.gov/search")!
        components.queryItems = [.init(name: "q", value: query),
                                 .init(name: "media_type", value: "image")]
        guard let url = components.url else { throw SourceError.badURL }

        let response = try await HTTPClient.json(Response.self, from: url)
        let iso = ISO8601DateFormatter()

        let images: [CosmicImage] = response.collection.items.compactMap { item in
            guard let meta = item.data.first,
                  let preview = item.links?.first?.href,
                  let thumbURL = URL(string: preview) else { return nil }
            // Any size suffix → ~orig (reliably present & high-res).
            let origString = preview.replacingOccurrences(
                of: "~(thumb|small|medium|large)\\.(jpg|jpeg|png)",
                with: "~orig.$2", options: .regularExpression)
            guard let imageURL = URL(string: origString) else { return nil }
            return CosmicImage(
                id: "\(id)-\(meta.nasa_id ?? preview)",
                title: meta.title ?? name,
                credit: "NASA",
                explanation: meta.description,
                date: meta.date_created.flatMap { iso.date(from: $0) },
                sourceID: id,
                pageURL: URL(string: "https://images.nasa.gov/details/\(meta.nasa_id ?? "")"),
                imageURL: imageURL,
                thumbURL: thumbURL,
                isVideo: false,
                resolution: .uhd)
        }
        guard !images.isEmpty else { throw SourceError.empty }
        return Array(images.shuffled().prefix(max(limit, 1)))
    }
}

// MARK: - The themed collections

extension NASASearchSource {
    static let earth = NASASearchSource(
        id: "earth", name: "Earth from Space", subtitle: "Our pale blue dot",
        symbol: "globe.europe.africa.fill", accentHex: 0x5EF2B0,
        queries: ["earth from space", "blue marble earth", "earthrise",
                  "earth from iss", "earth limb sunrise"])

    static let solar = NASASearchSource(
        id: "solar", name: "Solar System", subtitle: "Planets & moons",
        symbol: "sun.max.fill", accentHex: 0xFFD166,
        queries: ["saturn cassini", "jupiter great red spot", "mars surface",
                  "pluto new horizons", "enceladus", "io volcano"])

    static let stations = NASASearchSource(
        id: "stations", name: "Space Stations", subtitle: "ISS & spacecraft",
        symbol: "antenna.radiowaves.left.and.right", accentHex: 0xFF8A5E,
        queries: ["international space station", "iss cupola earth",
                  "spacewalk astronaut", "space station solar array"])

    /// Interstellar — themed after the film: black holes, accretion disks,
    /// gravitational lensing and wormholes.
    static let interstellar = NASASearchSource(
        id: "interstellar", name: "Interstellar", subtitle: "Black holes & wormholes",
        symbol: "hurricane", accentHex: 0x8B7CFF,
        queries: ["black hole", "accretion disk black hole", "black hole simulation",
                  "supermassive black hole", "gravitational lensing"])
}
