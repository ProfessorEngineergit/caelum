import AppKit

/// Extracts a luminous accent colour from an image — the signature "the UI
/// wears the cosmos" move. Rather than a muddy average, we downsample and pick
/// the most vivid representative pixel, then normalise it into a bright,
/// saturated accent suitable for the aurora system.
enum DominantColor {
    static let fallback = NSColor(hex: 0x8B7CFF)

    static func accent(from image: NSImage) -> NSColor {
        let side = 24
        guard let rep = downsample(image, side: side) else { return fallback }

        var best: (score: CGFloat, color: NSColor)?
        for y in 0..<side {
            for x in 0..<side {
                guard let pixel = rep.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { continue }
                var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
                pixel.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
                guard b > 0.12, b < 0.97 else { continue }   // skip near-black / blown-out
                let score = s * sqrt(b)
                if best == nil || score > best!.score { best = (score, pixel) }
            }
        }

        guard let chosen = best?.color else { return fallback }
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        chosen.getHue(&h, saturation: &s, brightness: &b, alpha: &a)
        return NSColor(hue: h,
                       saturation: min(max(s, 0.45), 0.9),
                       brightness: 0.92,
                       alpha: 1)
    }

    static func accent(fromFileURL url: URL) -> NSColor? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        return accent(from: image)
    }

    private static func downsample(_ image: NSImage, side: Int) -> NSBitmapImageRep? {
        guard let rep = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0) else { return nil }
        rep.size = NSSize(width: side, height: side)

        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
        image.draw(in: NSRect(x: 0, y: 0, width: side, height: side))
        NSGraphicsContext.restoreGraphicsState()
        return rep
    }
}
