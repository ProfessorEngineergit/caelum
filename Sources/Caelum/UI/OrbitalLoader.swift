import SwiftUI

/// The signature loading state — an aurora arc orbiting a still point. No
/// spinners anywhere in Caelum.
struct OrbitalLoader: View {
    var tint: Color = Theme.Palette.auroraViolet
    var size: CGFloat = 36
    @State private var spin = false

    var body: some View {
        ZStack {
            Circle()
                .stroke(Theme.Palette.hairline, lineWidth: 2)
                .frame(width: size, height: size)
            Circle()
                .trim(from: 0, to: 0.2)
                .stroke(Theme.Gradients.auroraAngular,
                        style: StrokeStyle(lineWidth: 2.6, lineCap: .round))
                .frame(width: size, height: size)
                .rotationEffect(.degrees(spin ? 360 : 0))
            Circle()
                .fill(tint)
                .frame(width: size * 0.16, height: size * 0.16)
                .shadow(color: tint.opacity(0.8), radius: 4)
        }
        .onAppear {
            withAnimation(Theme.Motion.orbit) { spin = true }
        }
    }
}
