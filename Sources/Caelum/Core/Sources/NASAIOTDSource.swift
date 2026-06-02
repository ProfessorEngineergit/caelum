import Foundation

/// NASA "Image of the Day" — the agency's curated daily feed spanning deep
/// space, Earth science, missions and astronauts. A plain RSS feed with a
/// full-resolution image enclosure per item. No API key required.
/// https://www.nasa.gov/feeds/iotd-feed/
struct NASAIOTDSource: ImageSource {
    let id = "nasaiotd"
    let name = "NASA Image of the Day"
    let subtitle = "The agency's daily pick"
    let symbol = "globe.europe.africa.fill"
    let accentHex: UInt32 = 0xFF8A5E

    private let feedURL = URL(string: "https://www.nasa.gov/feeds/iotd-feed/")!

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let data = try await HTTPClient.data(from: feedURL)
        let items = RSSParser.parse(data)
        let images: [CosmicImage] = items.compactMap { item in
            guard let raw = item.imageURL, let imageURL = URL(string: raw),
                  raw.lowercased().contains(".jpg") || raw.lowercased().contains(".png")
            else { return nil }
            return CosmicImage(
                id: "nasaiotd-\(raw)",
                title: item.title.isEmpty ? "NASA Image of the Day" : item.title,
                credit: "NASA",
                explanation: item.descriptionText?.strippedHTML,
                date: nil,
                sourceID: id,
                pageURL: item.link.flatMap(URL.init(string:)),
                imageURL: imageURL,
                thumbURL: imageURL,
                isVideo: false)
        }
        return Array(images.prefix(limit))
    }
}
