import Foundation

/// Hidden diagnostic: `Caelum --smoke-test` fetches AND downloads the latest
/// image from every source, then reports real pixel dimensions / resolution.
/// This catches sources that return metadata but whose image won't actually load.
enum SmokeTest {
    static func run() {
        let group = DispatchGroup()
        group.enter()
        Task {
            print("Caelum smoke-test · \(SourceRegistry.all.count) sources (fetch + download)\n")
            var ok = 0
            for source in SourceRegistry.all {
                do {
                    let image = try await source.fetchLatestImage()
                    let file = try await ImageCache.shared.localURL(for: image)
                    let dims = ImageCache.shared.pixelSize(of: file)
                    let res = dims.map { ResolutionHint.classify(width: $0.width, height: $0.height).rawValue } ?? "??"
                    let dimStr = dims.map { "\($0.width)×\($0.height)" } ?? "unknown"
                    ok += 1
                    print("✓ \(source.id.padded(13)) [\(res.padded(2))] \(dimStr.padded(11)) \(image.title.prefix(38))")
                } catch {
                    print("✗ \(source.id.padded(13)) FAILED: \(error.localizedDescription)")
                }
            }
            print("\n\(ok)/\(SourceRegistry.all.count) sources produced a usable image.")
            group.leave()
        }
        group.wait()
        exit(0)
    }
}

private extension String {
    func padded(_ width: Int) -> String {
        count >= width ? self : self + String(repeating: " ", count: width - count)
    }
}
