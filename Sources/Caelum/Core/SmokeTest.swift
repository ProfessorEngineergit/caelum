import Foundation

/// Hidden diagnostic: `Caelum --smoke-test` fetches the latest image from every
/// registered source and prints the result, then exits. Used during development
/// and in CI to confirm every source's parsing still works.
enum SmokeTest {
    static func run() {
        let group = DispatchGroup()
        group.enter()
        Task {
            print("Caelum source smoke-test · \(SourceRegistry.all.count) sources\n")
            var ok = 0
            for source in SourceRegistry.all {
                do {
                    let image = try await source.fetchLatestImage()
                    ok += 1
                    let kind = image.isVideo ? "[video]" : "[image]"
                    print("✓ \(source.id.padded(10)) \(kind) \(image.title.prefix(48))")
                    print("    \(image.imageURL.absoluteString)")
                } catch {
                    print("✗ \(source.id.padded(10)) \(error.localizedDescription)")
                }
            }
            print("\n\(ok)/\(SourceRegistry.all.count) sources returned an image.")
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
