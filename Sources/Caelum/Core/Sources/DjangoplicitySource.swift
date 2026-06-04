import Foundation

/// Shared base for the three observatory feeds that run on ESO's "Djangoplicity"
/// CMS and expose identical RSS: ESA/Hubble, ESA/Webb and ESO. The feed gives an
/// image `<enclosure>` per item; we upgrade the "/screen/" path to "/large/" for
/// a crisper wallpaper and skip any video items.
struct DjangoplicitySource: ImageSource {
    let id: String
    let name: String
    let subtitle: String
    let symbol: String
    let accentHex: UInt32
    let feedURL: URL
    let creditLine: String
    let typicalResolution: ResolutionHint

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let data = try await HTTPClient.data(from: feedURL)
        let items = RSSParser.parse(data)
        let images: [CosmicImage] = items.compactMap { item in
            guard let raw = item.imageURL,
                  raw.lowercased().contains(".jpg") || raw.lowercased().contains(".png"),
                  let display = URL(string: upgradeResolution(raw)),
                  let thumb = URL(string: raw)
            else { return nil }
            return CosmicImage(
                id: "\(id)-\(raw)",
                title: item.title.isEmpty ? name : item.title,
                credit: creditLine,
                explanation: item.descriptionText?.strippedHTML,
                date: nil,
                sourceID: id,
                pageURL: item.link.flatMap(URL.init(string:)),
                imageURL: display,
                thumbURL: thumb,
                isVideo: false)
        }
        return Array(images.prefix(limit))
    }

    /// Djangoplicity serves several sizes under predictable paths.
    private func upgradeResolution(_ url: String) -> String {
        url.replacingOccurrences(of: "/screen/", with: "/large/")
           .replacingOccurrences(of: "/thumb/", with: "/large/")
    }
}

extension DjangoplicitySource {
    static let hubble = DjangoplicitySource(
        id: "hubble", name: "ESA/Hubble", subtitle: "Picture of the Week",
        symbol: "scope", accentHex: 0x8B7CFF,
        feedURL: URL(string: "https://esahubble.org/images/potw/feed/")!,
        creditLine: "ESA/Hubble & NASA",
        typicalResolution: .uhd)

    static let webb = DjangoplicitySource(
        id: "webb", name: "James Webb", subtitle: "ESA/Webb Images",
        symbol: "circle.hexagongrid.fill", accentHex: 0xFFB45E,
        feedURL: URL(string: "https://esawebb.org/images/feed/")!,
        creditLine: "ESA/Webb, NASA & CSA",
        typicalResolution: .uhd)

    static let eso = DjangoplicitySource(
        id: "eso", name: "ESO", subtitle: "Picture of the Week",
        symbol: "mountain.2.fill", accentHex: 0x5EF2B0,
        feedURL: URL(string: "https://www.eso.org/public/images/potw/feed/")!,
        creditLine: "ESO",
        typicalResolution: .uhd)
}
