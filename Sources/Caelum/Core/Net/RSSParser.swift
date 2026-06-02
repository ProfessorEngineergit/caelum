import Foundation

/// One entry from an RSS feed.
struct RSSItem {
    var title = ""
    var link: String?
    var descriptionText: String?
    var pubDate: String?
    var imageURL: String?
    var imageType: String?
}

/// Minimal RSS reader built on Foundation's `XMLParser`. Captures `<title>`,
/// `<link>`, `<description>`, `<pubDate>` and the first image-bearing
/// `<enclosure>` / `<media:content>` per item. Used for the Djangoplicity feeds
/// (ESA/Hubble, ESA/Webb, ESO).
final class RSSParser: NSObject, XMLParserDelegate {

    static func parse(_ data: Data) -> [RSSItem] {
        let parser = RSSParser()
        let xml = XMLParser(data: data)
        xml.delegate = parser
        xml.parse()
        return parser.items
    }

    private var items: [RSSItem] = []
    private var current: RSSItem?
    private var buffer = ""
    private var insideItem = false

    func parser(_ parser: XMLParser, didStartElement element: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attrs: [String: String]) {
        let name = (qName ?? element).lowercased()
        switch name {
        case "item", "entry":
            insideItem = true
            current = RSSItem()
        case "enclosure", "media:content", "media:thumbnail":
            // Prefer a real image enclosure; ignore videos.
            let type = attrs["type"] ?? ""
            let urlString = attrs["url"]
            let looksImage = type.hasPrefix("image") ||
                (urlString?.lowercased().contains(".jpg") ?? false) ||
                (urlString?.lowercased().contains(".png") ?? false)
            if insideItem, current?.imageURL == nil, looksImage, let urlString {
                current?.imageURL = urlString
                current?.imageType = type
            }
        default:
            break
        }
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { buffer += string }

    func parser(_ parser: XMLParser, foundCDATA CDATABlock: Data) {
        buffer += String(decoding: CDATABlock, as: UTF8.self)
    }

    func parser(_ parser: XMLParser, didEndElement element: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let name = (qName ?? element).lowercased()
        let text = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        switch name {
        case "title":       if insideItem { current?.title = text }
        case "link":        if insideItem, current?.link == nil { current?.link = text }
        case "description", "summary": if insideItem { current?.descriptionText = text }
        case "pubdate", "published", "updated": if insideItem { current?.pubDate = text }
        case "item", "entry":
            if let item = current { items.append(item) }
            current = nil
            insideItem = false
        default:
            break
        }
        buffer = ""
    }
}
