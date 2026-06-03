import SwiftUI

/// Mirrors `Preferences` with `@Published` properties so SwiftUI controls stay
/// in sync, and performs side effects (launch-at-login registration, rotation
/// rescheduling) as values change.
@MainActor
final class SettingsModel: ObservableObject {
    private let scheduler: Scheduler

    @Published var autoDaily: Bool        { didSet { Preferences.shared.autoDailyRefresh = autoDaily } }
    @Published var setOnAllScreens: Bool  { didSet { Preferences.shared.setOnAllScreens = setOnAllScreens } }
    @Published var rotateLibrary: Bool    { didSet { Preferences.shared.rotateLibrary = rotateLibrary; scheduler.rescheduleRotation() } }
    @Published var rotateMinutes: Int     { didSet { Preferences.shared.rotateMinutes = rotateMinutes; scheduler.rescheduleRotation() } }
    @Published var dynamicAccent: Bool    { didSet { Preferences.shared.dynamicAccent = dynamicAccent } }
    @Published var chime: Bool            { didSet { Preferences.shared.chimeOnUpdate = chime } }
    @Published var ambientEnabled: Bool   { didSet { Preferences.shared.ambientEnabled = ambientEnabled } }
    @Published var ambientIdleMinutes: Int { didSet { Preferences.shared.ambientIdleSeconds = ambientIdleMinutes * 60 } }
    @Published var ambientInterval: Int   { didSet { Preferences.shared.ambientIntervalSeconds = ambientInterval } }
    @Published var launchAtLogin: Bool    { didSet { LaunchAtLogin.set(launchAtLogin) } }
    @Published var nasaKey: String        { didSet { Preferences.shared.nasaAPIKey = nasaKey } }

    init(scheduler: Scheduler) {
        self.scheduler = scheduler
        let prefs = Preferences.shared
        autoDaily = prefs.autoDailyRefresh
        setOnAllScreens = prefs.setOnAllScreens
        rotateLibrary = prefs.rotateLibrary
        rotateMinutes = prefs.rotateMinutes
        dynamicAccent = prefs.dynamicAccent
        chime = prefs.chimeOnUpdate
        ambientEnabled = prefs.ambientEnabled
        ambientIdleMinutes = max(1, prefs.ambientIdleSeconds / 60)
        ambientInterval = prefs.ambientIntervalSeconds
        launchAtLogin = LaunchAtLogin.isEnabled
        nasaKey = prefs.usingDemoKey ? "" : prefs.nasaAPIKey
    }
}

/// Slide-up settings overlay.
struct SettingsView: View {
    @EnvironmentObject var app: AppState
    @StateObject private var model: SettingsModel

    init(scheduler: Scheduler) {
        _model = StateObject(wrappedValue: SettingsModel(scheduler: scheduler))
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.Palette.hairline)
            ScrollView {
                VStack(spacing: Theme.Metrics.space5) {
                    section("Wallpaper") {
                        toggle("Refresh daily automatically", $model.autoDaily)
                        toggle("Set on all displays", $model.setOnAllScreens)
                        toggle("Rotate through the library", $model.rotateLibrary)
                        if model.rotateLibrary {
                            stepperRow("Every", value: $model.rotateMinutes, range: 5...720, step: 5, unit: "min")
                        }
                    }
                    section("Ambient mode") {
                        toggle("Enable on idle", $model.ambientEnabled)
                        stepperRow("Start after", value: $model.ambientIdleMinutes, range: 1...60, step: 1, unit: "min")
                        stepperRow("Seconds per image", value: $model.ambientInterval, range: 4...60, step: 1, unit: "s")
                    }
                    section("Appearance") {
                        toggle("Tint interface to the image", $model.dynamicAccent)
                        toggle("Chime when wallpaper updates", $model.chime)
                    }
                    section("Startup") {
                        toggle("Launch Caelum at login", $model.launchAtLogin)
                    }
                    section("NASA API key") {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("DEMO_KEY", text: $model.nasaKey)
                                .textFieldStyle(.plain)
                                .font(Theme.Fonts.mono(12))
                                .foregroundStyle(Theme.Palette.textPrimary)
                                .padding(10)
                                .glassCard(cornerRadius: 10, fill: 0.6)
                            Text("APOD, EPIC and other NASA feeds share a key. The bundled DEMO_KEY is rate-limited — a free personal key lifts the limits.")
                                .font(Theme.Fonts.body(11))
                                .foregroundStyle(Theme.Palette.textTertiary)
                            linkButton("Get a free key →", "https://api.nasa.gov")
                        }
                    }
                    aboutSection
                }
                .padding(Theme.Metrics.space5)
            }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: 560)
        .background(Theme.Palette.obsidian1.opacity(0.985))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
        .tint(app.accent)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("Settings").font(Theme.Fonts.display(18))
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Button {
                withAnimation(Theme.Motion.gentle) { app.showSettings = false }
            } label: { Image(systemName: "xmark") }
                .buttonStyle(GlassIconButtonStyle(size: 34))
        }
        .padding(Theme.Metrics.space5)
    }

    private func section<Content: View>(_ title: String, @ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.space3) {
            Text(title).microLabel(app.accent)
            VStack(spacing: Theme.Metrics.space3) { content() }
                .padding(Theme.Metrics.space4)
                .glassCard()
        }
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Toggle(isOn: binding) {
            Text(title).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Palette.textPrimary)
        }
        .toggleStyle(.switch)
    }

    private func stepperRow(_ title: String, value: Binding<Int>,
                            range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack {
            Text(title).font(Theme.Fonts.body(13)).foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(Theme.Fonts.mono(12)).foregroundStyle(app.accent)
            Stepper("", value: value, in: range, step: step).labelsHidden()
        }
    }

    private func linkButton(_ title: String, _ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
        } label: {
            Text(title).font(Theme.Fonts.title(12)).foregroundStyle(app.accent)
        }
        .buttonStyle(.plain)
    }

    private var aboutSection: some View {
        VStack(spacing: 6) {
            Text("CAELUM").font(Theme.Fonts.micro(11)).tracking(4)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Version 1.0.0 · MIT License")
                .font(Theme.Fonts.mono(10)).foregroundStyle(Theme.Palette.textTertiary)
            HStack(spacing: 14) {
                linkButton("GitHub", "https://github.com/ProfessorEngineergit/caelum")
                linkButton("Website", "https://professorengineergit.github.io/caelum/")
            }
            Text("Imagery © NASA · ESA · ESO and respective owners")
                .font(Theme.Fonts.body(10)).foregroundStyle(Theme.Palette.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, Theme.Metrics.space2)
    }
}
