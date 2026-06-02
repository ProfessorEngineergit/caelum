import SwiftUI
import AppKit

// MARK: - Caelum Design Language · "Obsidian Glass / Aurora"
//
// A precision instrument carved from black glass that carries the cosmos.
// Every token here is a deliberate part of the visual system — colors,
// gradients, typography, motion and metrics. Mission control meets Swiss
// typography meets a pane of floating obsidian.

enum Theme {

    // MARK: Palette

    enum Palette {
        /// Deepest background — the void.
        static let obsidian0 = Color(hex: 0x06070D)
        /// Primary panel background, faint blue-violet undertone.
        static let obsidian1 = Color(hex: 0x0A0B16)
        /// Raised surface (cards, chips).
        static let obsidian2 = Color(hex: 0x141627)
        /// Hover / pressed raised surface.
        static let obsidian3 = Color(hex: 0x1D2036)

        /// Aurora accent stops — used sparingly for energy.
        static let auroraCyan    = Color(hex: 0x5EE7FF)
        static let auroraViolet  = Color(hex: 0x8B7CFF)
        static let auroraMagenta = Color(hex: 0xFF6AD5)

        /// Text.
        static let textPrimary   = Color(hex: 0xF4F6FF)
        static let textSecondary = Color(hex: 0x9AA0BC)
        static let textTertiary  = Color(hex: 0x5A6080)

        /// Luminous hairline (inner stroke) and dividers.
        static let hairline      = Color.white.opacity(0.10)
        static let hairlineStrong = Color.white.opacity(0.16)

        /// Semantic.
        static let positive = Color(hex: 0x5EF2B0)
        static let warning  = Color(hex: 0xFFD166)
        static let danger   = Color(hex: 0xFF6B81)
    }

    // MARK: Gradients

    enum Gradients {
        /// The signature aurora sweep: cyan → violet → magenta.
        static let aurora = LinearGradient(
            colors: [Palette.auroraCyan, Palette.auroraViolet, Palette.auroraMagenta],
            startPoint: .topLeading, endPoint: .bottomTrailing
        )

        static let auroraHorizontal = LinearGradient(
            colors: [Palette.auroraCyan, Palette.auroraViolet, Palette.auroraMagenta],
            startPoint: .leading, endPoint: .trailing
        )

        /// Angular variant for orbital rings / loaders.
        static let auroraAngular = AngularGradient(
            colors: [Palette.auroraCyan, Palette.auroraViolet, Palette.auroraMagenta, Palette.auroraCyan],
            center: .center
        )

        /// Panel base gradient — subtle top-to-bottom deepening.
        static let panel = LinearGradient(
            colors: [Palette.obsidian1.opacity(0.86), Palette.obsidian0.opacity(0.92)],
            startPoint: .top, endPoint: .bottom
        )

        /// Bottom scrim over hero imagery so text stays legible.
        static func heroScrim(_ height: CGFloat = 1) -> LinearGradient {
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0.0),
                    .init(color: Palette.obsidian0.opacity(0.25), location: 0.5),
                    .init(color: Palette.obsidian0.opacity(0.92), location: 1.0)
                ],
                startPoint: .top, endPoint: .bottom
            )
        }
    }

    // MARK: Typography · "Instrument"

    enum Fonts {
        /// Hero / display title.
        static func display(_ size: CGFloat = 22) -> Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        /// Section / card title.
        static func title(_ size: CGFloat = 15) -> Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        /// Body copy (explanations).
        static func body(_ size: CGFloat = 13) -> Font {
            .system(size: size, weight: .regular, design: .default)
        }
        /// All-caps micro labels with wide tracking ("TODAY · NASA APOD").
        static func micro(_ size: CGFloat = 10) -> Font {
            .system(size: size, weight: .semibold, design: .rounded)
        }
        /// Monospaced metadata with tabular figures (dates, resolutions).
        static func mono(_ size: CGFloat = 11) -> Font {
            .system(size: size, weight: .medium, design: .monospaced)
        }
    }

    // MARK: Metrics · 8pt grid

    enum Metrics {
        static let popoverWidth: CGFloat = 360
        static let heroHeight: CGFloat = 220

        static let radiusPanel: CGFloat = 22
        static let radiusCard: CGFloat = 16
        static let radiusChip: CGFloat = 11
        static let radiusButton: CGFloat = 14

        static let space1: CGFloat = 4
        static let space2: CGFloat = 8
        static let space3: CGFloat = 12
        static let space4: CGFloat = 16
        static let space5: CGFloat = 20
        static let space6: CGFloat = 24

        static let microTracking: CGFloat = 1.6
    }

    // MARK: Motion · "Orbital" — spring physics everywhere

    enum Motion {
        /// Standard responsive spring for taps and state changes.
        static let snappy = Animation.spring(response: 0.34, dampingFraction: 0.82)
        /// Gentle spring for sheets and large transitions.
        static let gentle = Animation.spring(response: 0.5, dampingFraction: 0.86)
        /// Bouncy emphasis for the brand mark / success moments.
        static let bouncy = Animation.spring(response: 0.42, dampingFraction: 0.62)
        /// Long, breathing loop for the ambient aurora.
        static let breathe = Animation.easeInOut(duration: 6).repeatForever(autoreverses: true)
        /// Continuous rotation for the orbital loader.
        static let orbit = Animation.linear(duration: 1.1).repeatForever(autoreverses: false)
    }
}

// MARK: - Color / NSColor hex helpers

extension Color {
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255
        let g = Double((hex >> 8) & 0xFF) / 255
        let b = Double(hex & 0xFF) / 255
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

extension NSColor {
    convenience init(hex: UInt32, alpha: CGFloat = 1) {
        let r = CGFloat((hex >> 16) & 0xFF) / 255
        let g = CGFloat((hex >> 8) & 0xFF) / 255
        let b = CGFloat(hex & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: alpha)
    }
}
