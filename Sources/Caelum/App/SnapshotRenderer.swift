import SwiftUI
import AppKit

/// Renders the popover to a PNG offscreen (no screen-recording permission) for
/// the README and marketing site. Usage: `Caelum --render-popover <out.png> [hero.jpg]`
@MainActor
enum SnapshotRenderer {
    static func run(outPath: String, heroPath: String?) {
        let heroImage: NSImage? = {
            if let heroPath, let img = NSImage(contentsOfFile: heroPath) { return img }
            return ImageCache.shared.cachedFiles().first.flatMap { NSImage(contentsOf: $0) }
        }()

        let sample = CosmicImage(
            id: "snapshot",
            title: "A Stellar Nursery in the Carina Nebula",
            credit: "NASA, ESA, CSA, STScI",
            explanation: "The “Cosmic Cliffs” of NGC 3324 — towering peaks of gas and dust sculpted by the ultraviolet radiation and stellar winds of hot, young stars.",
            date: Date(),
            sourceID: "apod",
            pageURL: URL(string: "https://apod.nasa.gov/apod/astropix.html"),
            imageURL: URL(string: "https://apod.nasa.gov/apod/astropix.html")!,
            thumbURL: nil)

        let app = AppState()
        let accent = heroImage.map { Color(nsColor: DominantColor.accent(from: $0)) } ?? Theme.Palette.auroraViolet
        app.prepareSnapshot(image: sample, hero: heroImage, accent: accent)

        let view = PopoverView()
            .environmentObject(app)
            .environment(\.isSnapshot, true)
            .frame(width: Theme.Metrics.popoverWidth, height: 560)
            .background(Theme.Palette.obsidian0)
            .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))

        let renderer = ImageRenderer(content: view)
        renderer.scale = 2

        guard let nsImage = renderer.nsImage,
              let tiff = nsImage.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write(Data("render-popover: failed\n".utf8))
            exit(1)
        }
        try? png.write(to: URL(fileURLWithPath: outPath))
        print("Rendered popover → \(outPath)")
        exit(0)
    }
}
