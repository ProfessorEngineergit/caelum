import Foundation

/// A themed source backed by the NASA Image & Video Library search API.
///
/// NASA's library is noisy (award ceremonies, hardware photos, concept art), so
/// each collection is constrained two ways:
///   • `idPrefix` — only keep assets whose `nasa_id` starts with this (e.g.
///     "PIA" = JPL planetary imagery, "iss" = astronaut photography).
///   • a shared noise filter on the title.
/// Results upgrade to the reliably high-resolution `~orig` asset; `ImageCache`
/// falls back to the thumbnail if that ever fails, so a cell is never broken.
struct NASASearchSource: ImageSource {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let accentHex: UInt32
    let queries: [String]
    var idPrefix: String? = nil
    var typicalResolution: ResolutionHint { .uhd }

    private static let noise = [
        "award", "concept", "illustration", "artist", "mockup", "training",
        "ceremony", "portrait", "receives", "administrator", "briefing",
        "conference", "interview", "press", "team", "crew ", "flight control",
        "hangout", "anniversary", "patch", "logo", "poster", "tweetup",
    ]

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
        // Deterministic per day so the prefetcher caches exactly what's shown.
        let dayIndex = Int(Date().timeIntervalSince1970 / 86_400)
        let query = queries[dayIndex % queries.count]
        var components = URLComponents(string: "https://images-api.nasa.gov/search")!
        components.queryItems = [.init(name: "q", value: query),
                                 .init(name: "media_type", value: "image")]
        guard let url = components.url else { throw SourceError.badURL }

        let response = try await HTTPClient.json(Response.self, from: url)
        let iso = ISO8601DateFormatter()

        let images: [CosmicImage] = response.collection.items.compactMap { item -> CosmicImage? in
            guard let meta = item.data.first,
                  let title = meta.title,
                  let preview = item.links?.first?.href,
                  let thumbURL = URL(string: preview) else { return nil }
            // ID-prefix gate (planetary / astronaut imagery only).
            if let prefix = idPrefix,
               !(meta.nasa_id?.uppercased().hasPrefix(prefix.uppercased()) ?? false) { return nil }
            // Noise gate.
            let lower = title.lowercased()
            if Self.noise.contains(where: { lower.contains($0) }) { return nil }

            let origString = preview.replacingOccurrences(
                of: "~(thumb|small|medium|large)\\.(jpg|jpeg|png)",
                with: "~orig.$2", options: .regularExpression)
            guard let imageURL = URL(string: origString) else { return nil }
            return CosmicImage(
                id: "\(id)-\(meta.nasa_id ?? preview)",
                title: title,
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
        return Array(images.prefix(max(limit, 1)))
    }
}

// MARK: - The themed collections

extension NASASearchSource {
    static let earth = NASASearchSource(
        id: "earth", name: "Earth from Space", subtitle: "Astronaut photography",
        symbol: "globe.europe.africa.fill", accentHex: 0x5EF2B0,
        queries: ["earth airglow", "earth at night", "earth aurora from space",
                  "earth limb sunrise", "earth from station"],
        idPrefix: "iss")

    static let solar = NASASearchSource(
        id: "solar", name: "Solar System", subtitle: "Planets & moons",
        symbol: "sun.max.fill", accentHex: 0xFFD166,
        // Restricted to planets whose JPL imagery is reliably 4K+.
        queries: ["saturn cassini", "jupiter", "mars surface"],
        idPrefix: "PIA")

    static let stations = NASASearchSource(
        id: "stations", name: "Space Stations", subtitle: "ISS in orbit",
        symbol: "antenna.radiowaves.left.and.right", accentHex: 0xFF8A5E,
        queries: ["international space station orbit", "space station earth",
                  "international space station aurora"])

    /// Interstellar — themed after the film: black holes, nebulae, galaxies.
    static let interstellar = NASASearchSource(
        id: "interstellar", name: "Interstellar", subtitle: "Black holes & galaxies",
        symbol: "hurricane", accentHex: 0x8B7CFF,
        queries: ["black hole", "crab nebula", "carina nebula",
                  "spiral galaxy", "supernova remnant"])
}
