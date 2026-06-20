import SwiftUI
import AppKit

/// A full-screen, cinematic first-run experience — Arc-style: the screen fades to
/// black, a glowing aurora orb blooms in with a chime, then a few calm steps with
/// big type carry you to "Enter Caelum". Owns no audio; calls `onChime` on each
/// transition so the controller can play it.
struct OnboardingView: View {
    let onComplete: (String) -> Void
    var onChime: (Bool) -> Void = { _ in }
    var onDrone: () -> Void = {}

    @State private var step = 0
    @State private var apiKey = ""
    @State private var revealed = false
    @FocusState private var keyFocused: Bool

    private let lastStep = 4

    var body: some View {
        ZStack {
            OnboardingBackground(intensity: revealed ? (step == 0 ? 1.0 : 0.62) : 0)
                .animation(.easeOut(duration: 1.9), value: revealed)
                .animation(.easeInOut(duration: 0.8), value: step)

            // The illuminating sphere — large on the splash, then it rises and
            // shrinks to sit above the text on later steps.
            AuroraOrb(energised: step == 0)
                .frame(width: orbSize, height: orbSize)
                .offset(y: step == 0 ? 0 : -orbRise)
                .opacity(revealed ? 1 : 0)
                .scaleEffect(revealed ? 1 : 0.6)
                .animation(.spring(response: 1.1, dampingFraction: 0.7), value: step)
                .animation(.easeOut(duration: 1.4), value: revealed)

            VStack {
                Spacer()
                stepContent
                    .frame(maxWidth: 560)
                    .padding(.horizontal, 48)
                Spacer()
                footer
            }
            .opacity(revealed ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black)
        .environment(\.colorScheme, .dark)
        .onExitCommand { onComplete(apiKey) }   // Esc always escapes the takeover
        .onAppear {
            // Hold on pure black for a beat — "man sieht nichts" — then the nebula
            // blooms in and the boom lands at the very same instant.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                onDrone()
                withAnimation(.easeOut(duration: 1.9)) { revealed = true }
            }
            // Auto-advance the splash into the first message.
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.8) {
                if step == 0 { advance() }
            }
        }
    }

    private var orbSize: CGFloat { step == 0 ? 260 : 150 }
    private var orbRise: CGFloat { 210 }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0:
            VStack(spacing: 18) {
                Text("CAELUM")
                    .font(.system(size: 30, weight: .semibold, design: .rounded))
                    .tracking(14)
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text("The cosmos, every day.")
                    .font(.system(size: 17, design: .rounded))
                    .foregroundStyle(Theme.Palette.textSecondary)
            }
            .transition(.opacity)
        case 1:
            messageStep(
                eyebrow: "WELCOME",
                title: "Your desktop becomes\na window to the universe.",
                body: "Every day, Caelum places a breathtaking image of space on your wallpaper — quietly, from your menu bar.")
        case 2:
            VStack(spacing: 26) {
                messageStep(
                    eyebrow: "NINE LENSES ON THE SKY",
                    title: "From the great\nobservatories — and films.",
                    body: "NASA APOD, Hubble, James Webb, ESO, curated Deep-Space, Earth, Solar System, Spacecraft — and a Sci-Fi gallery.")
                sourceGlyphRow
            }
            .transition(.opacity)
        case 3:
            VStack(spacing: 22) {
                messageStep(
                    eyebrow: "ONE LAST THING",
                    title: "Add your free NASA key\nfor the fastest APOD.",
                    body: "APOD runs on NASA's API. The bundled DEMO_KEY is shared and rate-limited — a personal key (free, 30 seconds) makes it fast and reliable.")
                keyField
            }
            .transition(.opacity)
        default:
            messageStep(
                eyebrow: "YOU'RE ALL SET",
                title: "Welcome to Caelum.",
                body: "Click the orbit icon in your menu bar anytime. The first image is already on its way to your desktop.")
        }
    }

    private func messageStep(eyebrow: String, title: String, body: String) -> some View {
        VStack(spacing: 18) {
            Text(eyebrow)
                .font(.system(size: 12, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.Palette.auroraViolet)
            Text(title)
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .lineSpacing(2)
                .foregroundStyle(Theme.Palette.textPrimary)
                .shadow(color: .black.opacity(0.5), radius: 16, y: 6)
            Text(body)
                .font(.system(size: 16))
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: 460)
        }
        .transition(.opacity)
    }

    private var sourceGlyphRow: some View {
        HStack(spacing: 16) {
            ForEach(["sparkles", "scope", "circle.hexagongrid.fill", "mountain.2.fill",
                     "globe.europe.africa.fill", "sun.max.fill", "hurricane"], id: \.self) { sym in
                Image(systemName: sym)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(width: 44, height: 44)
                    .background(Circle().fill(Theme.Palette.obsidian2.opacity(0.6)))
                    .overlay(Circle().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            }
        }
    }

    private var keyField: some View {
        VStack(spacing: 12) {
            TextField("Paste your NASA API key (optional)", text: $apiKey)
                .textFieldStyle(.plain)
                .font(.system(size: 15, design: .monospaced))
                .foregroundStyle(Theme.Palette.textPrimary)
                .multilineTextAlignment(.center)
                .focused($keyFocused)
                .padding(.vertical, 14).padding(.horizontal, 18)
                .frame(maxWidth: 420)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.Palette.obsidian2.opacity(0.7)))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(keyFocused ? Theme.Palette.auroraViolet.opacity(0.7) : Theme.Palette.hairline, lineWidth: 1))
                .onSubmit { advance() }
            Button { NSWorkspace.shared.open(URL(string: "https://api.nasa.gov")!) } label: {
                Label("Get a free key at api.nasa.gov", systemImage: "arrow.up.forward.app")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.Palette.auroraCyan)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Footer (dots + continue)

    private var footer: some View {
        VStack(spacing: 26) {
            HStack(spacing: 9) {
                ForEach(0...lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                                        : AnyShapeStyle(Theme.Palette.textTertiary.opacity(0.4)))
                        .frame(width: i == step ? 22 : 7, height: 7)
                        .animation(Theme.Motion.snappy, value: step)
                }
            }
            .opacity(step == 0 ? 0 : 1)

            Button(action: advance) {
                Text(primaryLabel)
                    .frame(minWidth: 220)
            }
            .buttonStyle(AuroraPillButtonStyle())
            .keyboardShortcut(.defaultAction)
            .opacity(step == 0 ? 0 : 1)

            if step == 3 {
                Button { apiKey = ""; advance() } label: {
                    Text("Skip — use the shared key")
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 64)
        .animation(Theme.Motion.gentle, value: step)
    }

    private var primaryLabel: String {
        switch step {
        case 1, 2: return "Continue"
        case 3: return apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Continue" : "Save key & continue"
        default: return "Enter Caelum"
        }
    }

    private func advance() {
        if step >= lastStep {
            onComplete(apiKey)
            return
        }
        onChime(true)
        withAnimation(.easeInOut(duration: 0.55)) { step += 1 }
        if step == 3 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { keyFocused = true }
        }
    }
}

// MARK: - The glowing aurora orb ("illuminating sphere")

private struct AuroraOrb: View {
    var energised: Bool

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            let breathe = 1.0 + 0.04 * sin(t * 1.1)
            ZStack {
                // Outer bloom
                Circle()
                    .fill(RadialGradient(colors: [Theme.Palette.auroraViolet.opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: 220))
                    .blur(radius: 30)
                    .scaleEffect(energised ? 1.6 : 1.3)
                // Core sphere
                Circle()
                    .fill(AngularGradient(
                        colors: [Theme.Palette.auroraCyan, Theme.Palette.auroraViolet,
                                 Theme.Palette.auroraMagenta, Theme.Palette.auroraCyan],
                        center: .center, angle: .degrees(t * 18)))
                    .overlay(
                        Circle().fill(RadialGradient(
                            colors: [.white.opacity(0.5), .clear],
                            center: .init(x: 0.35, y: 0.3), startRadius: 0, endRadius: 90)))
                    .frame(width: 92, height: 92)
                    .scaleEffect(breathe)
                    .shadow(color: Theme.Palette.auroraViolet.opacity(0.7), radius: 28)
                // Orbit ring + dot
                let ringW: CGFloat = 150, ringH: CGFloat = 64
                Ellipse()
                    .strokeBorder(Theme.Palette.textPrimary.opacity(0.5), lineWidth: 1.4)
                    .frame(width: ringW, height: ringH)
                    .rotationEffect(.degrees(-22))
                Circle()
                    .fill(Theme.Palette.auroraCyan)
                    .frame(width: 9, height: 9)
                    .shadow(color: Theme.Palette.auroraCyan, radius: 6)
                    .offset(x: cos(t * 0.9) * (ringW / 2), y: sin(t * 0.9) * (ringH / 2))
                    .rotationEffect(.degrees(-22))
            }
        }
    }
}

// MARK: - Background (obsidian + aurora glows + twinkling starfield)

private struct OnboardingBackground: View {
    var intensity: Double = 1

    var body: some View {
        ZStack {
            Color.black
            Group {
                RadialGradient(colors: [Theme.Palette.obsidian2.opacity(0.9), .black],
                               center: .center, startRadius: 0, endRadius: 700)
                NebulaView()                       // the wabbernder Nebel
                RadialGradient(colors: [Theme.Palette.auroraViolet.opacity(0.16), .clear],
                               center: .init(x: 0.2, y: 0.15), startRadius: 0, endRadius: 520)
                RadialGradient(colors: [Theme.Palette.auroraCyan.opacity(0.12), .clear],
                               center: .init(x: 0.85, y: 0.85), startRadius: 0, endRadius: 520)
                Starfield()
            }
            .opacity(intensity)
        }
        .ignoresSafeArea()
    }
}

/// A slow, undulating nebula — a few coloured glows that drift, breathe and screen
/// over one another behind a heavy blur, so the cloud forever churns ("wabbert").
private struct NebulaView: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            GeometryReader { geo in
                let center = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.46)
                ZStack {
                    blob(Theme.Palette.auroraViolet,  center, t, speed: 0.07,  phase: 0.0, radius: 360, drift: 150)
                    blob(Theme.Palette.auroraCyan,    center, t, speed: 0.06,  phase: 2.1, radius: 300, drift: 185)
                    blob(Theme.Palette.auroraMagenta, center, t, speed: 0.085, phase: 4.2, radius: 280, drift: 130)
                    blob(Color(nsColor: NSColor(hex: 0x3A66FF)), center, t, speed: 0.05, phase: 1.0, radius: 260, drift: 205)
                }
                .blur(radius: 80)
                .blendMode(.screen)
            }
        }
        .ignoresSafeArea()
    }

    private func blob(_ color: Color, _ base: CGPoint, _ t: Double,
                      speed: Double, phase: Double, radius: CGFloat, drift: CGFloat) -> some View {
        let dx = CGFloat(sin(t * speed + phase)) * drift
        let dy = CGFloat(cos(t * speed * 0.8 + phase * 1.3)) * (drift * 0.7)
        let breathe = 1.0 + 0.22 * sin(t * speed * 1.6 + phase)
        return Circle()
            .fill(RadialGradient(colors: [color.opacity(0.55), .clear],
                                 center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .scaleEffect(breathe)
            .position(x: base.x + dx, y: base.y + dy)
    }
}

private struct Starfield: View {
    private let stars: [(CGPoint, CGFloat, Double)] = (0..<160).map { _ in
        (CGPoint(x: .random(in: 0...1), y: .random(in: 0...1)),
         CGFloat.random(in: 0.5...1.8),
         Double.random(in: 0...6.28))
    }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { ctx, size in
                for (p, r, phase) in stars {
                    let tw = 0.4 + 0.6 * (0.5 + 0.5 * sin(t * 0.9 + phase))
                    let rect = CGRect(x: p.x * size.width, y: p.y * size.height, width: r, height: r)
                    ctx.opacity = tw
                    ctx.fill(Path(ellipseIn: rect), with: .color(tw > 0.8 ? Theme.Palette.auroraCyan : .white))
                }
            }
        }
        .ignoresSafeArea()
    }
}
