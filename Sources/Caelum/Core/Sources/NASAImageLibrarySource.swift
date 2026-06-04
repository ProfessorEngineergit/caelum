import Foundation

/// The NASA Image and Video Library. We rotate through a set of evocative
/// queries so the feed stays fresh, and upgrade the preview thumbnail to the
/// "~large" asset for wallpaper use.
/// https://images-api.nasa.gov
struct NASAImageLibrarySource: ImageSource {
    let id = "nasalib"
    let name = "NASA Library"
    let subtitle = "Image & Video Library"
    let symbol = "books.vertical.fill"
    let accentHex: UInt32 = 0xFF6AD5
    let typicalResolution: ResolutionHint = .hd

    private let queries = ["nebula", "galaxy", "aurora borealis", "supernova",
                           "star cluster", "spiral galaxy", "deep field",
                           "planetary nebula", "Saturn", "Jupiter", "Orion"]

    private struct Response: Decodable {
        struct Collection: Decodable { let items: [Item] }
        struct Item: Decodable {
            let data: [Meta]
            let links: [Link]?
        }
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
        let query = queries.randomElement() ?? "nebula"
        var components = URLComponents(string: "https://images-api.nasa.gov/search")!
        components.queryItems = [.init(name: "q", value: query),
                                 .init(name: "media_type", value: "image")]
        guard let url = components.url else { throw SourceError.badURL }

        let response = try await HTTPClient.json(Response.self, from: url)
        let iso = ISO8601DateFormatter()

        let images: [CosmicImage] = response.collection.items.compactMap { item in
            guard let meta = item.data.first,
                  let thumb = item.links?.first?.href,
                  let thumbURL = URL(string: thumb) else { return nil }
            let large = thumb.replacingOccurrences(
                of: "~(thumb|small|medium)\\.jpg", with: "~large.jpg",
                options: .regularExpression)
            guard let imageURL = URL(string: large) else { return nil }
            return CosmicImage(
                id: "nasalib-\(meta.nasa_id ?? thumb)",
                title: meta.title ?? "NASA Image",
                credit: "NASA",
                explanation: meta.description,
                date: meta.date_created.flatMap { iso.date(from: $0) },
                sourceID: id,
                pageURL: URL(string: "https://images.nasa.gov/details/\(meta.nasa_id ?? "")"),
                imageURL: imageURL,
                thumbURL: thumbURL,
                isVideo: false)
        }
        return Array(images.shuffled().prefix(limit))
    }
}
