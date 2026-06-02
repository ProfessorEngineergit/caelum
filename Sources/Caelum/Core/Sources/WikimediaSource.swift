import Foundation

/// Wikimedia Commons "Picture of the Day", via the Wikipedia featured-content
/// feed. We upscale the feed's thumbnail to a large rendered JPEG/PNG so even
/// huge or SVG originals stay wallpaper-friendly. No API key required (a polite
/// User-Agent is — set globally in HTTPClient).
struct WikimediaSource: ImageSource {
    let id = "wikimedia"
    let name = "Wikimedia"
    let subtitle = "Picture of the Day"
    let symbol = "globe"
    let accentHex: UInt32 = 0xB8C0FF

    private struct Feed: Decodable {
        struct Image: Decodable {
            struct Src: Decodable { let source: String }
            struct Text: Decodable { let text: String? }
            let title: String?
            let thumbnail: Src?
            let image: Src?
            let file_page: String?
            let description: Text?
            let artist: Text?
        }
        let image: Image?
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let count = min(max(limit, 1), 10)
        let calendar = Calendar(identifier: .gregorian)
        let today = Date()

        let results = await withTaskGroup(of: CosmicImage?.self) { group -> [CosmicImage] in
            for offset in 0..<count {
                let day = calendar.date(byAdding: .day, value: -offset, to: today) ?? today
                group.addTask { try? await Self.fetchDay(day) }
            }
            var images: [CosmicImage] = []
            for await image in group { if let image { images.append(image) } }
            return images
        }
        return results.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private static func fetchDay(_ day: Date) async throws -> CosmicImage? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyyy/MM/dd"
        let url = URL(string:
            "https://api.wikimedia.org/feed/v1/wikipedia/en/featured/\(f.string(from: day))")!

        let feed = try await HTTPClient.json(Feed.self, from: url)
        guard let potd = feed.image,
              let thumb = potd.thumbnail?.source,
              let thumbURL = URL(string: thumb) else { return nil }

        // Upscale "/640px-..." → "/2560px-..." for a crisp rendered image.
        let largeString = thumb.replacingOccurrences(
            of: "/[0-9]+px-", with: "/2560px-", options: .regularExpression)
        guard let imageURL = URL(string: largeString) else { return nil }

        let title = (potd.title ?? "Picture of the Day")
            .replacingOccurrences(of: "File:", with: "")
        return CosmicImage(
            id: "wikimedia-\(f.string(from: day))",
            title: title,
            credit: potd.artist?.text?.strippedHTML ?? "Wikimedia Commons",
            explanation: potd.description?.text?.strippedHTML,
            date: day,
            sourceID: "wikimedia",
            pageURL: potd.file_page.flatMap(URL.init(string:)),
            imageURL: imageURL,
            thumbURL: thumbURL,
            isVideo: false)
    }
}
