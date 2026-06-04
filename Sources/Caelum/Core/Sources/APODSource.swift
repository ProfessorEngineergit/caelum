import Foundation

/// ⭐ The star of Caelum: NASA's Astronomy Picture of the Day.
/// Primary path is the JSON API; if that's unavailable (NASA's APOD API is
/// famously flaky) we transparently fall back to scraping the always-up APOD
/// website so the star never goes dark.
/// https://api.nasa.gov/planetary/apod
struct APODSource: ImageSource {
    let id = "apod"
    let name = "NASA APOD"
    let subtitle = "Astronomy Picture of the Day"
    let symbol = "sparkles"
    let accentHex: UInt32 = 0x5EE7FF
    let usesNASAKey = true
    let typicalResolution: ResolutionHint = .uhd

    private var apiKey: String { Preferences.shared.nasaAPIKey }
    private static let website = "https://apod.nasa.gov/apod/"

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        do {
            let dtos = try decode(try await HTTPClient.data(from: apiURL(limit: limit)))
            let mapped = dtos.compactMap(map)
                .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
            guard !mapped.isEmpty else { throw SourceError.empty }
            return mapped
        } catch {
            // API down — scrape today's APOD page instead.
            return [try await fetchFromWebsite()]
        }
    }

    private func apiURL(limit: Int) -> URL {
        var components = URLComponents(string: "https://api.nasa.gov/planetary/apod")!
        var query = [URLQueryItem(name: "api_key", value: apiKey),
                     URLQueryItem(name: "thumbs", value: "true")]
        if limit > 1 {
            let cal = Calendar(identifier: .gregorian)
            let end = Date()
            let start = cal.date(byAdding: .day, value: -(limit - 1), to: end) ?? end
            query.append(.init(name: "start_date", value: CaelumDates.ymd.string(from: start)))
            query.append(.init(name: "end_date", value: CaelumDates.ymd.string(from: end)))
        }
        components.queryItems = query
        return components.url!
    }

    // MARK: - JSON path

    private struct DTO: Decodable {
        let date: String?
        let title: String?
        let explanation: String?
        let url: String?
        let hdurl: String?
        let media_type: String?
        let copyright: String?
        let thumbnail_url: String?
    }

    private func decode(_ data: Data) throws -> [DTO] {
        let decoder = JSONDecoder()
        if let array = try? decoder.decode([DTO].self, from: data) { return array }
        if let single = try? decoder.decode(DTO.self, from: data) { return [single] }
        throw SourceError.decoding("APOD response not understood")
    }

    private func map(_ dto: DTO) -> CosmicImage? {
        let isVideo = (dto.media_type ?? "image") == "video"
        let primary = dto.hdurl ?? dto.url
        let displayString = isVideo ? (dto.thumbnail_url ?? dto.url) : primary
        guard let displayString, let imageURL = URL(string: displayString) else { return nil }
        let date = dto.date.flatMap { CaelumDates.ymd.date(from: $0) }
        return CosmicImage(
            id: "apod-\(dto.date ?? UUID().uuidString)",
            title: dto.title ?? "Astronomy Picture of the Day",
            credit: dto.copyright?.replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? "NASA APOD",
            explanation: dto.explanation,
            date: date,
            sourceID: id,
            pageURL: pageURL(for: date),
            imageURL: imageURL,
            thumbURL: isVideo ? imageURL : dto.url.flatMap(URL.init(string:)),
            isVideo: isVideo,
            resolution: isVideo ? .sd : (dto.hdurl != nil ? .uhd : .hd))
    }

    private func pageURL(for date: Date?) -> URL? {
        guard let date else { return URL(string: Self.website + "astropix.html") }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyMMdd"
        return URL(string: Self.website + "ap\(f.string(from: date)).html")
    }

    // MARK: - Website fallback

    private func fetchFromWebsite() async throws -> CosmicImage {
        let html = try await HTTPClient.string(from: URL(string: Self.website + "astropix.html")!)
        guard let imagePath = Self.match(#"href="(image/[^"]+\.(?:jpg|jpeg|png|gif))""#, in: html),
              let imageURL = URL(string: Self.website + imagePath) else {
            throw SourceError.noImage
        }
        let afterImage = html.range(of: imagePath).map { String(html[$0.upperBound...]) } ?? html
        let title = Self.match(#"<b>\s*(.*?)\s*</b>"#, in: afterImage)?.strippedHTML
        let credit = Self.match(#"(?:Credit|Copyright)[^<]*</b>(.*?)</center>"#, in: afterImage)?.strippedHTML
        let explanation = Self.match(#"Explanation:\s*</b>(.*?)<p>"#, in: html)?.strippedHTML

        return CosmicImage(
            id: "apod-\(CaelumDates.ymd.string(from: Date()))",
            title: (title?.isEmpty == false ? title! : "Astronomy Picture of the Day"),
            credit: credit ?? "NASA APOD",
            explanation: explanation,
            date: Date(),
            sourceID: id,
            pageURL: URL(string: Self.website + "astropix.html"),
            imageURL: imageURL,
            thumbURL: imageURL,
            isVideo: false,
            resolution: .hd)   // website fallback: unknown HD but not verified UHD
    }

    /// First capture group of `pattern` in `text` (dot-matches-newline, case-insensitive).
    private static func match(_ pattern: String, in text: String) -> String? {
        guard let re = try? NSRegularExpression(
            pattern: pattern,
            options: [.dotMatchesLineSeparators, .caseInsensitive]) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        guard let m = re.firstMatch(in: text, range: range), m.numberOfRanges > 1,
              let r = Range(m.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}
