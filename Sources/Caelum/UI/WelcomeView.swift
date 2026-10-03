import SwiftUI

/// The panel the intro's jump lands on — a chrome-less sheet of real glass (it
/// blurs the stars behind it) floating over the drifting starfield.
///
/// * Setup (four unhurried steps): hello, pick your sky (every source has its own
///   voice), a few preferences, your first sky → "Enter Caelum" plays the outro.
/// * Update screen: the new version lands, the release's changes arrive one by
///   one, and words from them drift behind and beside the glass — darker than
///   the panel, one of them always in focus.
///
/// The Windows/Linux twin is desktop/src/renderer/intro.
struct WelcomeView: View {
    @ObservedObject var app: AppState
    @ObservedObject var model: IntroModel
    let audio: IntroAudio
    let onEnter: () -> Void
    let onClose: () -> Void

    @State private var step = 0
    @State private var autoDaily = Preferences.shared.autoDailyRefresh
    @State private var sameOnAllSpaces = Preferences.shared.sameWallpaperOnAllSpaces
    @State private var launchAtLogin = Preferences.shared.launchAtLogin
    @State private var autoUpdates = Preferences.shared.autoInstallUpdates
    @State private var shownChanges = 0
    @State private var landedAt = Date()

    private let lastStep = 3
    private var shown: Bool { model.revealed && !model.leaving }

    var body: some View {
        ZStack {
            if model.mode == .update && model.revealed {
                DriftingWords(words: Self.keywords(in: model.changes), since: landedAt)
                    .opacity(model.leaving ? 0 : 1)
                    .animation(.easeOut(duration: 0.5), value: model.leaving)
            }
            panel
                .scaleEffect(model.leaving ? 0.06 : (model.revealed ? 1 : 0.82))
                .opacity(shown ? 1 : 0)
                .blur(radius: shown ? 0 : 18)
                .allowsHitTesting(shown)
            if model.leaving {
                Spark()
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .environment(\.colorScheme, .dark)
        .onExitCommand { onClose() }      // Esc always gets you out
        .onChange(of: model.revealed) { revealed in
            guard revealed else { return }
            landedAt = Date()
            if model.mode == .update { revealChanges() }
        }
    }

    // MARK: - Panel

    private var panel: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 0) {
                ZStack {
                    content
                        .id(model.mode == .update ? -1 : step)
                        .transition(.asymmetric(
                            insertion: .opacity.combined(with: .offset(y: 18)),
                            removal: .opacity.combined(with: .offset(y: -18))))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                footer
            }
            .padding(.horizontal, 48)
            .padding(.top, 46)
            .padding(.bottom, 32)
            if model.mode == .intro {
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Theme.Palette.textTertiary)
                        .frame(width: 30, height: 30)
                        .background(Circle().fill(Color.white.opacity(0.06)))
                }
                .buttonStyle(.plain)
                .help("Close setup")
                .padding(18)
            }
        }
        .frame(width: 680, height: 560)
        .background(glass)
    }

    /// Real glass: the stars and drifting words behind the panel are blurred.
    private var glass: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        return ZStack {
            WithinWindowBlur().clipShape(shape)
            shape.fill(Theme.Palette.obsidian1.opacity(0.45))
            shape.fill(RadialGradient(colors: [Theme.Palette.auroraViolet.opacity(0.22), .clear],
                                      center: .topTrailing, startRadius: 0, endRadius: 440))
            shape.fill(RadialGradient(colors: [Theme.Palette.auroraCyan.opacity(0.10), .clear],
                                      center: .bottomLeading, startRadius: 0, endRadius: 380))
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.05)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var content: some View {
        if model.mode == .update {
            updateScreen
        } else {
            switch step {
            case 0: hello
            case 1: chooseSky
            case 2: preferences
            default: firstSky
            }
        }
    }

    // MARK: - Setup steps

    private var hello: some View {
        VStack(spacing: 20) {
            AuroraMark().frame(width: 96, height: 96)
            RevealText("CAELUM", letters: true, delay: 0.1)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(10)
                .foregroundStyle(Theme.Palette.textSecondary)
            RevealText("The cosmos, every day.", delay: 0.35)
                .font(.system(size: 42, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
            FadeIn(delay: 0.8) {
                Text("Each morning Caelum puts a new image of space on your desktop — from NASA, Hubble, Webb and ESO. Take a minute to make it yours.")
                    .font(.system(size: 15.5))
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .frame(maxWidth: 460)
            }
        }
    }

    private var chooseSky: some View {
        VStack(spacing: 22) {
            heading("CHOOSE YOUR SKY", "Where should your day begin?")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)],
                      spacing: 10) {
                ForEach(app.sources, id: \.id) { source in
                    sourceTile(source)
                }
            }
        }
    }

    private func sourceTile(_ source: ImageSource) -> some View {
        let selected = app.activeSourceID == source.id
        let tint = Color(hex: source.accentHex)
        return Button {
            audio.playSource(source.id)          // also on a repeat tap
            if !selected { app.selectSource(source.id) }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: source.symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(selected ? Color.black : tint)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(selected ? AnyShapeStyle(tint) : AnyShapeStyle(tint.opacity(0.14))))
                VStack(alignment: .leading, spacing: 1) {
                    Text(source.name)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                    Text(source.subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(selected ? tint.opacity(0.14) : Theme.Palette.obsidian2.opacity(0.6)))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(selected ? tint.opacity(0.7) : Theme.Palette.hairline, lineWidth: 1))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .animation(Theme.Motion.snappy, value: selected)
    }

    private var preferences: some View {
        VStack(spacing: 22) {
            heading("MAKE IT YOURS", "A few small choices.")
            VStack(spacing: 0) {
                preferenceRow("Refresh daily", "A new image on your desktop every morning.", $autoDaily)
                divider
                preferenceRow("Same wallpaper on every desktop", "Caelum follows you across all your Spaces.", $sameOnAllSpaces)
                divider
                preferenceRow("Launch at login", "Start quietly in the menu bar.", $launchAtLogin)
                divider
                preferenceRow("Install updates automatically", "New versions are always offered in the panel either way.", $autoUpdates)
            }
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Theme.Palette.obsidian2.opacity(0.55)))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            Text("No account and no API key — every source is open.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.Palette.textTertiary)
        }
    }

    private func preferenceRow(_ title: String, _ detail: String, _ value: Binding<Bool>) -> some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Text(detail)
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            Spacer(minLength: 0)
            Toggle("", isOn: value)
                .labelsHidden()
                .toggleStyle(.switch)
                .tint(Theme.Palette.auroraViolet)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 11)
    }

    private var divider: some View {
        Rectangle().fill(Theme.Palette.hairline).frame(height: 1).padding(.leading, 16)
    }

    private var firstSky: some View {
        VStack(spacing: 18) {
            heading("YOUR FIRST SKY", "Ready for lift-off.")
            ZStack(alignment: .bottomLeading) {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.Palette.obsidian2)
                if let hero = app.heroImage {
                    Image(nsImage: hero)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .transition(.opacity)
                } else {
                    OrbitalLoader(tint: Theme.Palette.auroraViolet, size: 28)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                LinearGradient(colors: [.clear, Theme.Palette.obsidian0.opacity(0.9)], startPoint: .center, endPoint: .bottom)
                VStack(alignment: .leading, spacing: 4) {
                    Text(app.activeSource.name.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .tracking(2)
                        .foregroundStyle(Theme.Palette.auroraCyan)
                    Text(app.current?.title ?? "Loading…")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                        .lineLimit(1)
                }
                .padding(16)
            }
            .frame(width: 584, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Theme.Palette.hairline, lineWidth: 1))
            .animation(.easeOut(duration: 0.5), value: app.heroImage != nil)
        }
    }

    private func heading(_ eyebrow: String, _ title: String) -> some View {
        VStack(spacing: 12) {
            FadeIn(delay: 0.05) {
                Text(eyebrow)
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.Palette.auroraViolet)
            }
            RevealText(title, delay: 0.12)
                .font(.system(size: 32, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    // MARK: - Update screen

    private var updateScreen: some View {
        VStack(spacing: 22) {
            FadeIn(delay: 0.05) {
                Text("CAELUM HAS BEEN UPDATED")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .tracking(3)
                    .foregroundStyle(Theme.Palette.auroraViolet)
            }
            HStack(alignment: .firstTextBaseline, spacing: 18) {
                FadeIn(delay: 0.2) {
                    Text("v\(model.fromVersion)")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .strikethrough(true, color: Color.white.opacity(0.25))
                        .foregroundStyle(Theme.Palette.textTertiary)
                }
                FadeIn(delay: 0.45) {
                    Text("→").font(.system(size: 26, weight: .bold)).foregroundStyle(Theme.Palette.textTertiary)
                }
                VersionLanding(text: "v\(model.toVersion)", delay: 0.7)
            }
            VStack(alignment: .leading, spacing: 10) {
                ForEach(Array(displayedChanges.enumerated()), id: \.offset) { index, line in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Circle()
                            .fill(Theme.Gradients.auroraHorizontal)
                            .frame(width: 8, height: 8)
                            .shadow(color: Theme.Palette.auroraViolet, radius: 5)
                        Text(line)
                            .font(.system(size: 16))
                            .foregroundStyle(index == shownChanges - 1 ? Theme.Palette.textPrimary : Theme.Palette.textSecondary)
                    }
                    .opacity(index < shownChanges ? 1 : 0)
                    .blur(radius: index < shownChanges ? 0 : 8)
                    .offset(x: index < shownChanges ? 0 : -14)
                    .animation(.spring(response: 0.7, dampingFraction: 0.8), value: shownChanges)
                }
            }
            .frame(maxWidth: 520, alignment: .leading)
        }
    }

    private var displayedChanges: [String] {
        model.changes.isEmpty ? ["Under-the-hood improvements."] : model.changes
    }

    /// The changes arrive one by one, each with its accent.
    private func revealChanges() {
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_700_000_000)
            // The release notes may still be loading — give them a moment.
            var waited = 0
            while model.changes.isEmpty && waited < 15 {
                try? await Task.sleep(nanoseconds: 100_000_000)
                waited += 1
            }
            for _ in displayedChanges {
                guard !model.leaving else { return }
                shownChanges += 1
                audio.play("line", volume: 0.9)
                try? await Task.sleep(nanoseconds: 950_000_000)
            }
        }
    }

    private static let stopWords: Set<String> = Set("""
    the and for with from into that this when then than your you are was were have has had not but all any its also \
    just only more less over under after before about their there here they them what which while will would should \
    could onto upon each every very much many some such like make made makes add adds added fix fixes fixed use uses used now new
    """.split(separator: " ").map(String.init))

    static func keywords(in changes: [String]) -> [String] {
        var seen = Set<String>()
        var words: [String] = []
        for line in changes {
            for raw in line.split(whereSeparator: { !$0.isLetter && !$0.isNumber && $0 != "-" && $0 != "'" }) {
                let word = String(raw)
                let key = word.lowercased()
                guard word.count >= 4, !stopWords.contains(key), !seen.contains(key) else { continue }
                seen.insert(key)
                words.append(word)
            }
        }
        return Array(words.prefix(18))
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button("Back") { go(to: step - 1) }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Palette.textTertiary)
                .opacity(step == 0 || model.mode == .update ? 0 : 1)
                .disabled(step == 0 || model.mode == .update)
                .frame(width: 90, alignment: .leading)
            Spacer()
            if model.mode == .intro {
                HStack(spacing: 8) {
                    ForEach(0...lastStep, id: \.self) { i in
                        Capsule()
                            .fill(i == step ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                                            : AnyShapeStyle(Theme.Palette.textTertiary.opacity(0.4)))
                            .frame(width: i == step ? 20 : 6, height: 6)
                    }
                }
                .animation(Theme.Motion.snappy, value: step)
            }
            Spacer()
            Button(primaryTitle, action: advance)
                .buttonStyle(AuroraPillButtonStyle())
                .keyboardShortcut(.defaultAction)
                .frame(width: 170)
        }
        .frame(height: 46)
    }

    private var primaryTitle: String {
        if model.mode == .update { return "Continue" }
        switch step {
        case 0: return "Begin"
        case lastStep: return "Enter Caelum"
        default: return "Continue"
        }
    }

    private func advance() {
        if model.mode == .update { onEnter(); return }
        if step == 2 { savePreferences() }
        guard step < lastStep else {
            onEnter()
            return
        }
        go(to: step + 1)
    }

    private func go(to target: Int) {
        guard (0...lastStep).contains(target) else { return }
        audio.play("step", volume: 0.8)
        withAnimation(.spring(response: 0.55, dampingFraction: 0.85)) { step = target }
    }

    private func savePreferences() {
        let prefs = Preferences.shared
        prefs.autoDailyRefresh = autoDaily
        prefs.sameWallpaperOnAllSpaces = sameOnAllSpaces
        prefs.autoInstallUpdates = autoUpdates
        if prefs.launchAtLogin != launchAtLogin {
            prefs.launchAtLogin = launchAtLogin
            LaunchAtLogin.set(launchAtLogin)
        }
    }
}

// MARK: - Pieces

/// NSVisualEffectView blending *within* the window — it blurs the Metal starfield
/// and the drifting words behind the panel, not the (hidden) desktop.
private struct WithinWindowBlur: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .hudWindow
        view.blendingMode = .withinWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

/// Text that arrives word by word (or letter by letter) out of a blur.
private struct RevealText: View {
    let units: [String]
    let delay: Double
    let step: Double
    let letters: Bool
    @State private var shown = false

    init(_ text: String, letters: Bool = false, delay: Double = 0) {
        units = letters ? text.map(String.init) : text.split(separator: " ").map { String($0) }
        self.delay = delay
        self.letters = letters
        step = letters ? 0.05 : 0.07
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(units.enumerated()), id: \.offset) { index, unit in
                Text(!letters && index < units.count - 1 ? unit + " " : unit)
                    .opacity(shown ? 1 : 0)
                    .blur(radius: shown ? 0 : 10)
                    .offset(y: shown ? 0 : 12)
                    .animation(.spring(response: 0.75, dampingFraction: 0.82).delay(delay + Double(index) * step), value: shown)
            }
        }
        .onAppear { shown = true }
    }
}

private struct FadeIn<Content: View>: View {
    let delay: Double
    @ViewBuilder let content: () -> Content
    @State private var shown = false

    var body: some View {
        content()
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 8)
            .offset(y: shown ? 0 : 10)
            .animation(.spring(response: 0.8, dampingFraction: 0.85).delay(delay), value: shown)
            .onAppear { shown = true }
    }
}

/// The new version number lands big and bright.
private struct VersionLanding: View {
    let text: String
    let delay: Double
    @State private var landed = false

    var body: some View {
        Text(text)
            .font(.system(size: 76, weight: .bold, design: .rounded))
            .foregroundStyle(Theme.Gradients.auroraHorizontal)
            .shadow(color: Theme.Palette.auroraViolet.opacity(0.55), radius: 24)
            .scaleEffect(landed ? 1 : 1.8)
            .opacity(landed ? 1 : 0)
            .blur(radius: landed ? 0 : 18)
            .animation(.spring(response: 0.9, dampingFraction: 0.62).delay(delay), value: landed)
            .onAppear { landed = true }
    }
}

/// Words from the release drifting behind and beside the glass — darker than the
/// panel; every 1.7 s another one comes into focus.
private struct DriftingWords: View {
    let words: [String]
    let since: Date

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSince(since)
            let focus = words.isEmpty ? -1 : Int(max(0, t - 1.2) / 1.7) % words.count
            GeometryReader { geo in
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let size = CGFloat(34 + (index * 53) % 90)
                    let speed = CGFloat(10 + (index * 7) % 26) * (index % 2 == 1 ? 1 : -1)
                    let span = geo.size.width + size * CGFloat(word.count) * 0.6
                    let x0 = CGFloat(Double(index) * 0.37).truncatingRemainder(dividingBy: 1) * span
                    let raw = (x0 + speed * CGFloat(t)).truncatingRemainder(dividingBy: span)
                    let x = raw < 0 ? raw + span : raw
                    let y = CGFloat(0.08 + (Double(index) * 0.618).truncatingRemainder(dividingBy: 0.84)) * geo.size.height
                    let focused = index == focus && t > 1.2
                    Text(word)
                        .font(.system(size: size, weight: .heavy, design: .rounded))
                        .fixedSize()
                        .foregroundStyle(focused ? Color(red: 0.84, green: 0.82, blue: 1).opacity(0.62)
                                                 : Color(red: 0.63, green: 0.65, blue: 0.82).opacity(0.16))
                        .shadow(color: focused ? Theme.Palette.auroraViolet.opacity(0.7) : .clear, radius: 24)
                        .blur(radius: focused ? 0 : 1.5)
                        .animation(.easeInOut(duration: 0.9), value: focused)
                        .position(x: x - size, y: y)
                }
            }
            .opacity(min(1, max(0, (t - 0.6) / 1.2)))
        }
        .allowsHitTesting(false)
    }
}

/// The point of light the panel collapses into at the start of the outro.
private struct Spark: View {
    @State private var phase: CGFloat = 0

    var body: some View {
        Circle()
            .fill(Color.white)
            .frame(width: 10, height: 10)
            .shadow(color: Color(red: 0.63, green: 0.59, blue: 1).opacity(0.9), radius: 30)
            .shadow(color: Theme.Palette.auroraCyan.opacity(0.5), radius: 80)
            .scaleEffect(phase < 0.5 ? 0.2 + phase * 2.8 : 1.6 - (phase - 0.5) * 2)
            .opacity(Double(phase < 0.4 ? phase / 0.4 : max(0, 1 - (phase - 0.4) / 0.6)))
            .onAppear { withAnimation(.easeOut(duration: 1.1).delay(0.2)) { phase = 1 } }
            .allowsHitTesting(false)
    }
}

private struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(Theme.Motion.snappy, value: configuration.isPressed)
    }
}

/// Caelum's mark for the intro: a glowing aurora sphere with an orbit and its dot.
private struct AuroraMark: View {
    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            ZStack {
                Circle()
                    .fill(RadialGradient(colors: [Theme.Palette.auroraViolet.opacity(0.55), .clear],
                                         center: .center, startRadius: 0, endRadius: 70))
                    .scaleEffect(1.5 + 0.06 * sin(t * 1.2))
                Circle()
                    .fill(AngularGradient(colors: [Theme.Palette.auroraCyan, Theme.Palette.auroraViolet,
                                                   Theme.Palette.auroraMagenta, Theme.Palette.auroraCyan],
                                          center: .center, angle: .degrees(t * 25)))
                    .frame(width: 46, height: 46)
                    .blur(radius: 1.5)
                Ellipse()
                    .strokeBorder(Color.white.opacity(0.35), lineWidth: 1)
                    .frame(width: 88, height: 30)
                    .rotationEffect(.degrees(-18))
                Circle()
                    .fill(Color.white)
                    .frame(width: 6, height: 6)
                    .shadow(color: Theme.Palette.auroraCyan, radius: 6)
                    .offset(x: 44 * cos(t * 1.4), y: 15 * sin(t * 1.4))
                    .rotationEffect(.degrees(-18))
            }
        }
    }
}
