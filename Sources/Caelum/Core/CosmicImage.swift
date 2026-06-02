import Foundation

/// A single image (or video day) from any source — the universal currency of Caelum.
struct CosmicImage: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let title: String
    let credit: String?
    let explanation: String?
    let date: Date?
    let sourceID: String
    let pageURL: URL?
    /// Best URL for display / wallpaper (highest resolution available).
    let imageURL: URL
    /// Optional smaller preview URL.
    let thumbURL: URL?
    /// True for APOD/ESO "video" days — never used as wallpaper.
    let isVideo: Bool

    init(id: String,
         title: String,
         credit: String? = nil,
         explanation: String? = nil,
         date: Date? = nil,
         sourceID: String,
         pageURL: URL? = nil,
         imageURL: URL,
         thumbURL: URL? = nil,
         isVideo: Bool = false) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.credit = credit
        self.explanation = explanation
        self.date = date
        self.sourceID = sourceID
        self.pageURL = pageURL
        self.imageURL = imageURL
        self.thumbURL = thumbURL
        self.isVideo = isVideo
    }

    /// The URL best suited for a quick preview (thumb if present, else full).
    var previewURL: URL { thumbURL ?? imageURL }
}

// MARK: - Shared date parsing helpers used by sources

enum CaelumDates {
    /// "yyyy-MM-dd"
    static let ymd: DateFormatter = formatter("yyyy-MM-dd")
    /// "yyyyMMdd" (Bing)
    static let compact: DateFormatter = formatter("yyyyMMdd")
    /// "yyyy-MM-dd HH:mm:ss" (NASA EPIC)
    static let epic: DateFormatter = formatter("yyyy-MM-dd HH:mm:ss")

    private static func formatter(_ format: String) -> DateFormatter {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(identifier: "UTC")
        f.dateFormat = format
        return f
    }

    /// Human-readable medium date for UI ("2 Jun 2026").
    static func display(_ date: Date?) -> String {
        guard let date else { return "" }
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US")
        f.dateFormat = "d MMM yyyy"
        return f.string(from: date)
    }
}

// MARK: - Light HTML stripping for feed descriptions

extension String {
    /// Removes tags and decodes a handful of common entities — good enough for
    /// the short descriptions that RSS feeds and Wikimedia hand us.
    var strippedHTML: String {
        var s = replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        let entities = ["&amp;": "&", "&lt;": "<", "&gt;": ">", "&quot;": "\"",
                        "&#39;": "'", "&nbsp;": " ", "&mdash;": "—", "&ndash;": "–"]
        for (k, v) in entities { s = s.replacingOccurrences(of: k, with: v) }
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
