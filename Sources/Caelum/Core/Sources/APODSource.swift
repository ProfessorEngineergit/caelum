import Foundation

/// ⭐ The star of Caelum: NASA's Astronomy Picture of the Day.
///
/// NASA retired the old `api.nasa.gov/planetary/apod` service when APOD moved to
/// science.nasa.gov (the legacy endpoint now answers with a placeholder logo for
/// every date). The replacement is a keyless WordPress JSON route:
///
///   • `…/apod-basic?per_page=N`   — the N newest entries (max 25)
///   • `…/apod-basic/yyMMdd`       — one specific day (the old `?date=` is ignored)
///
/// Differences from the legacy API that this source accounts for:
///   • no API key, no quota
///   • `hdurl` is the image for *every* entry (a poster frame for videos);
///     `url` is now the article page, not the image
///   • `hdurl` points at NASA's resizing CDN (`/dynamicimage/…?w=…&h=…`), which
///     caps output at ~1280 px whatever `w`/`h` say. The untouched original lives
///     at the same path under `/content/dam/` — that's the wallpaper; the resized
///     variant serves as the quick preview. `w`/`h` do give the original's size.
///   • `explanation`, `credit` and `copyright` are HTML fragments, and the
///     explanation carries site notices ("APOD's email…", "Tomorrow's picture…")
///   • `media_type` is `image`, `video` or `iframe`
///   • every entry also ships a full `basic_html` page — `_fields` trims the
///     response to what we read (~4× smaller); parsing works without it too
struct APODSource: ImageSource {
    let id = "apod"
    let name = "NASA APOD"
    let subtitle = "Astronomy Picture of the Day"
    let symbol = "sparkles"
    let accentHex: UInt32 = 0x5EE7FF
    let typicalResolution: ResolutionHint = .uhd

    private static let endpoint = "https://science.nasa.gov/wp-json/wp/v2/apod-basic"
    /// The route serves at most this many entries per page.
    private static let maxPerPage = 25
    /// The fields `DTO` reads — everything else (notably `basic_html`) is skipped.
    private static let fields = "date,title,explanation,credit,copyright,media_type,url,hdurl,permalink"

    func fetchRecent(limit: Int) async throws -> [CosmicImage] {
        let count = min(max(limit, 1), Self.maxPerPage)

        // Primary: one request for the newest entries.
        if let images = try? await fetchList(count: count), !images.isEmpty {
            return images
        }
        // Fallback: ask for the last few days one by one — resilient to the list
        // route misbehaving while the per-day route still works.
        let images = await fetchDayByDay(count: min(count, 8))
        guard !images.isEmpty else { throw SourceError.empty }
        return images
    }

    // MARK: - Requests

    private func fetchList(count: Int) async throws -> [CosmicImage] {
        var components = URLComponents(string: Self.endpoint)!
        components.queryItems = [URLQueryItem(name: "per_page", value: String(count)),
                                 URLQueryItem(name: "_fields", value: Self.fields)]
        guard let url = components.url else { throw SourceError.badURL }
        return Self.parse(try await HTTPClient.data(from: url))
    }

    private func fetchDayByDay(count: Int) async -> [CosmicImage] {
        let cal = Calendar(identifier: .gregorian)
        let today = Date()
        let days = (0..<count).compactMap { cal.date(byAdding: .day, value: -$0, to: today) }

        return await withTaskGroup(of: [CosmicImage].self) { group in
            for day in days {
                group.addTask {
                    // A missing day (404 — e.g. today's picture isn't out yet) is normal.
                    guard let url = URL(string: Self.endpoint + "/" + Self.yyMMdd(day) + "?_fields=" + Self.fields),
                          let data = try? await HTTPClient.data(from: url) else { return [] }
                    return Self.parse(data)
                }
            }
            var all: [CosmicImage] = []
            for await batch in group { all += batch }
            return all.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        }
    }

    // MARK: - Decoding

    /// One APOD entry. Every field is optional and decoded leniently — the route is
    /// WordPress-backed, so an empty value can arrive as `false`, `null` or `""`,
    /// and an error body (`{"code":…,"message":…}`) must not crash decoding.
    struct DTO: Decodable {
        let date: String?
        let title: String?
        let explanation: String?
        let credit: String?
        let copyright: String?
        let mediaType: String?
        let url: String?
        let hdurl: String?
        let permalink: String?

        private enum CodingKeys: String, CodingKey {
            case date, title, explanation, credit, copyright, url, hdurl, permalink
            case mediaType = "media_type"
        }

        init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            func string(_ key: CodingKeys) -> String? {
                (try? c.decodeIfPresent(String.self, forKey: key)) ?? nil
            }
            date = string(.date)
            title = string(.title)
            explanation = string(.explanation)
            credit = string(.credit)
            copyright = string(.copyright)
            mediaType = string(.mediaType)
            url = string(.url)
            hdurl = string(.hdurl)
            permalink = string(.permalink)
        }
    }

    /// Parses a response body — either a list of entries or a single entry — into
    /// images, newest first. Entries without a usable image URL are dropped.
    static func parse(_ data: Data) -> [CosmicImage] {
        let decoder = JSONDecoder()
        let dtos: [DTO]
        if let array = try? decoder.decode([DTO].self, from: data) {
            dtos = array
        } else if let single = try? decoder.decode(DTO.self, from: data) {
            dtos = [single]
        } else {
            return []
        }
        return dtos.compactMap(map)
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
    }

    private static func map(_ dto: DTO) -> CosmicImage? {
        // `hdurl` is the image (or a video's poster frame). `url` is the article page.
        guard let raw = dto.hdurl?.trimmingCharacters(in: .whitespacesAndNewlines),
              raw.lowercased().hasPrefix("http"),
              let hdURL = URL(string: raw) else { return nil }

        let isImage = (dto.mediaType ?? "image").lowercased() == "image"
        // Full-resolution original for the wallpaper; the CDN's resized copy as the
        // preview (and as ImageCache's fallback should the original ever fail).
        let imageURL = originalURL(for: hdURL) ?? hdURL
        let resolution: ResolutionHint = isImage
            ? (originalSize(of: hdURL).map { ResolutionHint.classify(width: $0.width, height: $0.height) } ?? .hd)
            : .sd
        let date = dto.date.flatMap { CaelumDates.ymd.date(from: String($0.prefix(10))) }

        let title = dto.title?.plainText ?? ""
        let credit = cleanCredit(dto.copyright) ?? cleanCredit(dto.credit) ?? "NASA APOD"

        return CosmicImage(
            id: "apod-\(date.map { CaelumDates.ymd.string(from: $0) } ?? UUID().uuidString)",
            title: title.isEmpty ? "Astronomy Picture of the Day" : title,
            credit: credit,
            explanation: cleanExplanation(dto.explanation),
            date: date,
            sourceID: "apod",
            pageURL: pageURL(permalink: dto.permalink, article: dto.url, date: date),
            imageURL: imageURL,
            thumbURL: hdURL,
            isVideo: !isImage,
            resolution: resolution)
    }

    // MARK: - Image URLs

    /// `https://assets.science.nasa.gov/dynamicimage/assets/science/…/x.jpg?w=…`
    ///   → `https://assets.science.nasa.gov/content/dam/science/…/x.jpg`
    /// `nil` when the URL isn't a resizing-CDN URL (then `hdurl` is used as is).
    static func originalURL(for hdURL: URL) -> URL? {
        let marker = "/dynamicimage/assets/"
        guard var components = URLComponents(url: hdURL, resolvingAgainstBaseURL: false),
              components.percentEncodedPath.hasPrefix(marker) else { return nil }
        components.percentEncodedPath = "/content/dam/"
            + components.percentEncodedPath.dropFirst(marker.count)
        components.query = nil
        return components.url
    }

    /// The original's pixel size from the CDN URL's `w`/`h` (NASA writes `0` when unknown).
    static func originalSize(of hdURL: URL) -> (width: Int, height: Int)? {
        let items = URLComponents(url: hdURL, resolvingAgainstBaseURL: false)?.queryItems ?? []
        func value(_ name: String) -> Int? {
            guard let raw = items.first(where: { $0.name == name })?.value,
                  let number = Int(raw), number > 0 else { return nil }
            return number
        }
        guard let w = value("w"), let h = value("h") else { return nil }
        return (w, h)
    }

    // MARK: - Text cleanup (the new route returns HTML)

    /// Plain text without the leading "Explanation:" label, and without the site
    /// notices appended after the body ("APOD's email for image submissions has
    /// changed…", "APOD's main NASA site is moving…", "Tomorrow's picture: …").
    static func cleanExplanation(_ html: String?) -> String? {
        guard var body = html else { return nil }
        // The notices follow the explanation as bold lines after a line break:
        // "…last sentence.<br><br><strong>APOD's email…</strong>…".
        if let notices = body.range(of: #"<br[^>]*>\s*(?:<br[^>]*>\s*)*<(?:strong|b)\b"#,
                                    options: [.regularExpression, .caseInsensitive]) {
            body = String(body[..<notices.lowerBound])
        }
        var text = body.plainText
        guard !text.isEmpty else { return nil }
        // Belt and braces, should a notice ever arrive without the bold markup.
        for teaser in ["APOD's email", "APOD’s email", "APOD's main NASA site", "APOD’s main NASA site",
                       "Tomorrow's picture", "Tomorrow’s picture", "Tomorrow's Picture", "Tomorrow’s Picture"] {
            if let range = text.range(of: teaser) {
                text = String(text[..<range.lowerBound])
            }
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.lowercased().hasPrefix("explanation:") {
            text = String(text.dropFirst("explanation:".count))
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Plain-text credit without a leading "Image Credit & Copyright:" style label.
    static func cleanCredit(_ html: String?) -> String? {
        guard var text = html?.plainText, !text.isEmpty else { return nil }
        let labels = ["image credit & copyright:", "image credit and copyright:",
                      "image credit:", "image copyright:", "credit & copyright:",
                      "credit:", "copyright:"]
        let lower = text.lowercased()
        if let label = labels.first(where: { lower.hasPrefix($0) }) {
            text = String(text.dropFirst(label.count))
        }
        text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    // MARK: - Links & dates

    private static func pageURL(permalink: String?, article: String?, date: Date?) -> URL? {
        for candidate in [permalink, article] {
            if let s = candidate?.trimmingCharacters(in: .whitespacesAndNewlines),
               s.lowercased().hasPrefix("http"), let url = URL(string: s) { return url }
        }
        guard let date else { return URL(string: "https://apod.nasa.gov/apod/astropix.html") }
        return URL(string: "https://apod.nasa.gov/apod/ap\(yyMMdd(date)).html")
    }

    /// "yyMMdd" — the per-day path component of the new route.
    private static func yyMMdd(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = "yyMMdd"
        return f.string(from: date)
    }
}

private extension String {
    /// HTML fragment → single-line plain text. Paragraph/line breaks become spaces
    /// (so "…end.</p><p>Next…" doesn't fuse), then tags and entities are stripped.
    var plainText: String {
        replacingOccurrences(of: "<(?:br|/p|/div|/li)[^>]*>", with: " ",
                             options: [.regularExpression, .caseInsensitive])
            .strippedHTML
            .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
