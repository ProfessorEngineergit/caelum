import Foundation

/// Bing's "Photo of the Day" archive — gorgeous daily landscape & nature shots,
/// available in 4K via the "_UHD.jpg" suffix. No API key required.
struct BingSource: ImageSource {
    let id = "bing"
    let name = "Bing"
    let subtitle = "Photo of the Day"
    let symbol = "photo.fill"
    let accentHex: UInt32 = 0x5EF2B0

    private struct Response: Decodable {
        struct Img: Decodable {
            let urlbase: String
            let copyright: String?
            let title: String?
            let startdate: String?
            let copyrightlink: String?
        }
        let images: [Img]
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let n = min(max(limit, 1), 8)
        let url = URL(string:
            "https://www.bing.com/HPImageArchive.aspx?format=js&idx=0&n=\(n)&mkt=en-US")!
        let response = try await HTTPClient.json(Response.self, from: url)

        return response.images.compactMap { img in
            guard let imageURL = URL(string: "https://www.bing.com\(img.urlbase)_UHD.jpg")
            else { return nil }
            let thumb = URL(string: "https://www.bing.com\(img.urlbase)_1920x1080.jpg")
            let title = (img.title?.isEmpty == false ? img.title : img.copyright) ?? "Bing Photo of the Day"
            return CosmicImage(
                id: "bing-\(img.startdate ?? img.urlbase)",
                title: title,
                credit: img.copyright,
                explanation: img.copyright,
                date: img.startdate.flatMap { CaelumDates.compact.date(from: $0) },
                sourceID: id,
                pageURL: img.copyrightlink.flatMap(URL.init(string:)),
                imageURL: imageURL,
                thumbURL: thumb,
                isVideo: false)
        }
    }
}
