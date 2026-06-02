import AppKit

// The Caelum mark: a planet, a single orbital ellipse, and an orbiting point.
// Rendered programmatically so it stays razor sharp at any size and works as a
// template image (auto-tinted by the menu bar for light/dark).

enum BrandGlyph {

    /// Monochrome template image for the menu bar status item.
    static func statusImage(size: CGFloat = 18, dotProgress: CGFloat = 0.1) -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { rect in
            let center = NSPoint(x: rect.midX, y: rect.midY)
            let orbitW = size * 0.94
            let orbitH = size * 0.40
            let tilt: CGFloat = -24

            // Orbit ellipse (rotated).
            let orbit = NSBezierPath(ovalIn: NSRect(
                x: center.x - orbitW / 2, y: center.y - orbitH / 2,
                width: orbitW, height: orbitH))
            orbit.lineWidth = max(1, size * 0.072)
            let xform = NSAffineTransform()
            xform.translateX(by: center.x, yBy: center.y)
            xform.rotate(byDegrees: tilt)
            xform.translateX(by: -center.x, yBy: -center.y)
            let rotatedOrbit = xform.transform(orbit)
            NSColor.black.setStroke()
            rotatedOrbit.stroke()

            // Planet at the center.
            let pr = size * 0.165
            NSColor.black.setFill()
            NSBezierPath(ovalIn: NSRect(x: center.x - pr, y: center.y - pr,
                                        width: pr * 2, height: pr * 2)).fill()

            // Orbiting point at `dotProgress` (0…1) around the ellipse.
            let t = dotProgress * 2 * .pi
            let ex = (orbitW / 2) * cos(t)
            let ey = (orbitH / 2) * sin(t)
            let rad = tilt * .pi / 180
            let dx = center.x + ex * cos(rad) - ey * sin(rad)
            let dy = center.y + ex * sin(rad) + ey * cos(rad)
            let dr = size * 0.11
            NSBezierPath(ovalIn: NSRect(x: dx - dr, y: dy - dr,
                                        width: dr * 2, height: dr * 2)).fill()
            return true
        }
        image.isTemplate = true
        return image
    }
}
