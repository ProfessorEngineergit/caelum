import SwiftUI

/// The setup you land in after the intro's hyperspace jump: a chrome-less glass
/// panel floating over the drifting stars. Four unhurried steps — hello, pick
/// your sky, a few preferences, and the library filling up.
struct WelcomeView: View {
    @ObservedObject var app: AppState
    @ObservedObject var model: IntroModel
    let onChime: () -> Void
    let onComplete: () -> Void

    @State private var step = 0
    @State private var autoDaily = Preferences.shared.autoDailyRefresh
    @State private var sameOnAllSpaces = Preferences.shared.sameWallpaperOnAllSpaces
    @State private var launchAtLogin = Preferences.shared.launchAtLogin
    @State private var autoUpdates = Preferences.shared.autoInstallUpdates

    private let lastStep = 3
    private var shown: Bool { model.revealed && !model.leaving }

    var body: some View {
        panel
            .scaleEffect(model.leaving ? 0.95 : (model.revealed ? 1 : 0.86))
            .opacity(shown ? 1 : 0)
            .blur(radius: shown ? 0 : 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .environment(\.colorScheme, .dark)
            .allowsHitTesting(shown)
            .onExitCommand { onComplete() }      // Esc always gets you out
    }

    // MARK: - Panel

    private var panel: some View {
        VStack(spacing: 0) {
            ZStack {
                stepContent
                    .id(step)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .offset(y: 16)),
                        removal: .opacity.combined(with: .offset(y: -16))))
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            footer
        }
        .padding(.horizontal, 44)
        .padding(.top, 44)
        .padding(.bottom, 32)
        .frame(width: 660, height: 520)
        .background(panelSurface)
    }

    private var panelSurface: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack {
            shape.fill(Theme.Palette.obsidian1.opacity(0.82))
            shape.fill(RadialGradient(colors: [Theme.Palette.auroraViolet.opacity(0.22), .clear],
                                      center: .topTrailing, startRadius: 0, endRadius: 420))
            shape.fill(RadialGradient(colors: [Theme.Palette.auroraCyan.opacity(0.10), .clear],
                                      center: .bottomLeading, startRadius: 0, endRadius: 360))
            shape.strokeBorder(LinearGradient(colors: [Color.white.opacity(0.24), Color.white.opacity(0.04)],
                                              startPoint: .top, endPoint: .bottom), lineWidth: 1)
        }
        .shadow(color: Theme.Palette.auroraViolet.opacity(0.35), radius: 60, y: 20)
        .shadow(color: .black.opacity(0.6), radius: 30, y: 16)
    }

    // MARK: - Steps

    @ViewBuilder
    private var stepContent: some View {
        switch step {
        case 0: hello
        case 1: chooseSky
        case 2: preferences
        default: library
        }
    }

    private var hello: some View {
        VStack(spacing: 22) {
            AuroraMark().frame(width: 92, height: 92)
            Text("CAELUM")
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .tracking(10)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("The cosmos, every day.")
                .font(.system(size: 38, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.Palette.textPrimary)
            Text("Each morning Caelum puts a new image of space on your desktop — from NASA, Hubble, Webb and ESO. Take a minute to make it yours.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: 440)
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
            guard !selected else { return }
            onChime()
            app.selectSource(source.id)
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
        .buttonStyle(.plain)
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

    private var library: some View {
        let done = app.setupProgress >= 1
        return VStack(spacing: 26) {
            heading(done ? "ALL SET" : "PREPARING YOUR LIBRARY",
                    done ? "Welcome to Caelum." : "Filling your library\nwith the cosmos.")
            Text(done
                 ? "Your sky is on the desktop. Caelum lives in the menu bar — click the orbit whenever you like."
                 : "A preview of every image is cached once, so switching sources and setting a wallpaper is instant.")
                .font(.system(size: 15))
                .lineSpacing(4)
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textSecondary)
                .frame(maxWidth: 440)
            VStack(spacing: 10) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.Palette.obsidian2.opacity(0.8))
                        Capsule()
                            .fill(Theme.Gradients.auroraHorizontal)
                            .frame(width: max(8, geo.size.width * app.setupProgress))
                            .shadow(color: Theme.Palette.auroraViolet.opacity(0.6), radius: 8)
                    }
                }
                .frame(width: 380, height: 8)
                .animation(.easeInOut(duration: 0.4), value: app.setupProgress)
                Text(done ? "Library ready" : "\(Int(app.setupProgress * 100)) %")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
        }
    }

    private func heading(_ eyebrow: String, _ title: String) -> some View {
        VStack(spacing: 12) {
            Text(eyebrow)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .tracking(3)
                .foregroundStyle(Theme.Palette.auroraViolet)
            Text(title)
                .font(.system(size: 30, weight: .semibold, design: .rounded))
                .multilineTextAlignment(.center)
                .foregroundStyle(Theme.Palette.textPrimary)
        }
    }

    // MARK: - Footer

    private var footer: some View {
        HStack(spacing: 16) {
            Button("Back") { go(to: step - 1) }
                .buttonStyle(.plain)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.Palette.textTertiary)
                .opacity(step == 0 ? 0 : 1)
                .disabled(step == 0)
                .frame(width: 90, alignment: .leading)
            Spacer()
            HStack(spacing: 8) {
                ForEach(0...lastStep, id: \.self) { i in
                    Capsule()
                        .fill(i == step ? AnyShapeStyle(Theme.Gradients.auroraHorizontal)
                                        : AnyShapeStyle(Theme.Palette.textTertiary.opacity(0.4)))
                        .frame(width: i == step ? 20 : 6, height: 6)
                }
            }
            .animation(Theme.Motion.snappy, value: step)
            Spacer()
            Button(primaryTitle, action: advance)
                .buttonStyle(AuroraPillButtonStyle())
                .keyboardShortcut(.defaultAction)
                .frame(width: 170)
        }
        .frame(height: 46)
    }

    private var primaryTitle: String {
        switch step {
        case 0: return "Begin"
        case lastStep: return "Enter Caelum"
        default: return "Continue"
        }
    }

    private func advance() {
        if step == 2 { savePreferences() }
        guard step < lastStep else {
            onComplete()
            return
        }
        go(to: step + 1)
    }

    private func go(to target: Int) {
        guard (0...lastStep).contains(target) else { return }
        onChime()
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
