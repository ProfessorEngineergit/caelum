import Foundation

/// NASA EPIC — full-disk natural-colour Earth from the DSCOVR spacecraft at L1.
/// https://api.nasa.gov/EPIC/api/natural
struct EPICSource: ImageSource {
    let id = "epic"
    let name = "NASA EPIC"
    let subtitle = "Earth from DSCOVR · L1"
    let symbol = "globe.americas.fill"
    let accentHex: UInt32 = 0x5EC8FF
    let usesNASAKey = true
    let typicalResolution: ResolutionHint = .hd

    private var apiKey: String { Preferences.shared.nasaAPIKey }

    private struct DTO: Decodable {
        let identifier: String
        let caption: String?
        let image: String
        let date: String
    }

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let url = URL(string: "https://api.nasa.gov/EPIC/api/natural?api_key=\(apiKey)")!
        let dtos = try await HTTPClient.json([DTO].self, from: url)

        let pathFormatter = DateFormatter()
        pathFormatter.locale = Locale(identifier: "en_US_POSIX")
        pathFormatter.timeZone = TimeZone(identifier: "UTC")
        pathFormatter.dateFormat = "yyyy/MM/dd"

        return dtos.prefix(limit).compactMap { dto -> CosmicImage? in
            guard let date = CaelumDates.epic.date(from: dto.date) else { return nil }
            let datePath = pathFormatter.string(from: date)
            let urlString =
                "https://api.nasa.gov/EPIC/archive/natural/\(datePath)/png/\(dto.image).png?api_key=\(apiKey)"
            guard let imageURL = URL(string: urlString) else { return nil }
            return CosmicImage(
                id: "epic-\(dto.identifier)",
                title: "Earth from DSCOVR",
                credit: "NASA EPIC / DSCOVR",
                explanation: dto.caption,
                date: date,
                sourceID: id,
                pageURL: URL(string: "https://epic.gsfc.nasa.gov/"),
                imageURL: imageURL,
                thumbURL: imageURL,
                isVideo: false)
        }
    }
}
