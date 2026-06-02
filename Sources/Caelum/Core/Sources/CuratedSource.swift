import Foundation

/// "Caelum Curated" — a hand-picked gallery of the most breathtaking imagery,
/// served as a JSON manifest from GitHub Pages so the collection can grow
/// without shipping an app update. Falls back to an embedded set of verified
/// classics when the manifest is unreachable (offline / before first deploy).
struct CuratedSource: ImageSource {
    let id = "curated"
    let name = "Caelum Curated"
    let subtitle = "Hand-picked highlights"
    let symbol = "star.circle.fill"
    let accentHex: UInt32 = 0xFFD166

    struct Item: Decodable {
        let title: String
        let credit: String?
        let explanation: String?
        let image: String
        let thumb: String?
        let page: String?
        let date: String?
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let items = (try? await HTTPClient.json([Item].self,
                                                from: Preferences.shared.curatedManifestURL))
            ?? Self.embedded
        let mapped = items.compactMap(map)
        guard !mapped.isEmpty else { throw SourceError.empty }
        return Array(mapped.prefix(max(limit, 1)))
    }

    private func map(_ item: Item) -> CosmicImage? {
        guard let imageURL = URL(string: item.image) else { return nil }
        return CosmicImage(
            id: "curated-\(item.image)",
            title: item.title,
            credit: item.credit,
            explanation: item.explanation,
            date: item.date.flatMap { CaelumDates.ymd.date(from: $0) },
            sourceID: id,
            pageURL: item.page.flatMap(URL.init(string:)),
            imageURL: imageURL,
            thumbURL: item.thumb.flatMap(URL.init(string:)),
            isVideo: false)
    }

    /// Verified, stable CDN URLs (checked to return 200). Mirrored in docs/curated.json.
    static let embedded: [Item] = [
        Item(title: "The Cosmic Cliffs of Carina",
             credit: "NASA, ESA, CSA, STScI",
             explanation: "The edge of the young star-forming region NGC 3324 in the Carina Nebula, captured by the James Webb Space Telescope in stunning infrared detail.",
             image: "https://cdn.esawebb.org/archives/images/large/weic2205a.jpg",
             thumb: "https://cdn.esawebb.org/archives/images/screen/weic2205a.jpg",
             page: "https://esawebb.org/images/weic2205a/", date: nil),
        Item(title: "Pillars of Creation (Webb)",
             credit: "NASA, ESA, CSA, STScI",
             explanation: "The iconic Pillars of Creation, re-imaged by JWST — towers of cool gas and dust in the Eagle Nebula where new stars are forming.",
             image: "https://cdn.esawebb.org/archives/images/large/weic2216a.jpg",
             thumb: "https://cdn.esawebb.org/archives/images/screen/weic2216a.jpg",
             page: "https://esawebb.org/images/weic2216a/", date: nil),
        Item(title: "Pillars of Creation (Hubble)",
             credit: "NASA, ESA, Hubble Heritage Team",
             explanation: "Hubble's celebrated 2015 view of the Pillars of Creation in the Eagle Nebula (M16).",
             image: "https://cdn.esahubble.org/archives/images/large/heic1509a.jpg",
             thumb: "https://cdn.esahubble.org/archives/images/screen/heic1509a.jpg",
             page: "https://esahubble.org/images/heic1509a/", date: nil),
        Item(title: "The Milky Way Above Paranal",
             credit: "ESO / Y. Beletsky",
             explanation: "A 360-degree panorama of the Milky Way arcing over ESO's Paranal Observatory in the Chilean Atacama Desert.",
             image: "https://cdn.eso.org/images/large/eso0932a.jpg",
             thumb: "https://cdn.eso.org/images/screen/eso0932a.jpg",
             page: "https://www.eso.org/public/images/eso0932a/", date: nil),
        Item(title: "ESO Deep Sky",
             credit: "ESO",
             explanation: "A deep-field view from ESO's Very Large Telescope.",
             image: "https://cdn.eso.org/images/large/eso1907a.jpg",
             thumb: "https://cdn.eso.org/images/screen/eso1907a.jpg",
             page: "https://www.eso.org/public/images/eso1907a/", date: nil),
        Item(title: "Hubble Heritage",
             credit: "NASA, ESA, Hubble",
             explanation: "A classic from the Hubble Space Telescope archive.",
             image: "https://cdn.esahubble.org/archives/images/large/heic0611b.jpg",
             thumb: "https://cdn.esahubble.org/archives/images/screen/heic0611b.jpg",
             page: "https://esahubble.org/images/heic0611b/", date: nil),
    ]
}
