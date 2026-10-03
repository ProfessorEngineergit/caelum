import SwiftUI

// MARK: - SettingsModel

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
    @Published var launchAtLogin: Bool    { didSet { Preferences.shared.launchAtLogin = launchAtLogin; LaunchAtLogin.set(launchAtLogin) } }
    @Published var autoInstallUpdates: Bool { didSet { Preferences.shared.autoInstallUpdates = autoInstallUpdates } }

    init(scheduler: Scheduler) {
        self.scheduler = scheduler
        let prefs = Preferences.shared
        autoDaily        = prefs.autoDailyRefresh
        setOnAllScreens  = prefs.setOnAllScreens
        rotateLibrary    = prefs.rotateLibrary
        rotateMinutes    = prefs.rotateMinutes
        dynamicAccent    = prefs.dynamicAccent
        chime            = prefs.chimeOnUpdate
        launchAtLogin    = prefs.launchAtLogin
        autoInstallUpdates = prefs.autoInstallUpdates
    }
}

// MARK: - SettingsView
// ⚠️ IMPORTANT: This view must NOT observe AppState.
// AppState publishes frequently (accent, heroImage, phase…) and causes a
// ScrollView + Stepper layout loop that pegs the CPU and freezes the app.
// All AppState access is passed in as plain closures / values at init time.

struct SettingsView: View {
    let onDismiss: () -> Void
    @StateObject private var model: SettingsModel
    /// Safe to observe: it publishes only on update-state changes (rare), unlike AppState.
    @ObservedObject private var updater: UpdateManager
    @Environment(\.isSnapshot) private var isSnapshot

    // Static accent — does not change on image updates, no re-renders.
    private let accent = Theme.Palette.auroraViolet

    init(scheduler: Scheduler, updater: UpdateManager, onDismiss: @escaping () -> Void) {
        _model = StateObject(wrappedValue: SettingsModel(scheduler: scheduler))
        _updater = ObservedObject(wrappedValue: updater)
        self.onDismiss = onDismiss
    }

    @ViewBuilder private var formContent: some View {
        // .frame(maxWidth:) prevents ideal-size propagation up through
        // the ScrollView — the root cause of the layout loop.
        VStack(spacing: Theme.Metrics.space5) {
            section("Wallpaper") {
                toggle("Refresh daily automatically", $model.autoDaily)
                toggle("Set on all displays", $model.setOnAllScreens)
                toggle("Rotate through the library", $model.rotateLibrary)
                if model.rotateLibrary {
                    stepperRow("Every", value: $model.rotateMinutes,
                               range: 5...720, step: 5, unit: "min")
                }
            }
            section("Appearance") {
                toggle("Tint interface to the image", $model.dynamicAccent)
                toggle("Chime when wallpaper updates", $model.chime)
            }
            section("Startup") {
                toggle("Launch Caelum at login", $model.launchAtLogin)
            }
            section("Updates") { updatesContent }
            aboutSection
        }
        .frame(maxWidth: .infinity)
        .padding(Theme.Metrics.space5)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().overlay(Theme.Palette.hairline)
            if isSnapshot {
                formContent   // ScrollView renders empty offscreen
            } else {
                ScrollView { formContent }
            }
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight)
        .background(Theme.Palette.obsidian1.opacity(0.985))
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
        .tint(Color(nsColor: NSColor(hex: 0x8B7CFF)))   // static violet, never re-renders
        .environment(\.colorScheme, .dark)
    }

    // MARK: - Pieces

    private var header: some View {
        HStack {
            Text("Settings")
                .font(Theme.Fonts.display(18))
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Button { onDismiss() } label: { Image(systemName: "xmark") }
                .buttonStyle(GlassIconButtonStyle(size: 34))
        }
        .padding(Theme.Metrics.space5)
    }

    private func section<C: View>(_ title: String, @ViewBuilder _ content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.space3) {
            Text(title).microLabel(accent)
            VStack(spacing: Theme.Metrics.space3) { content() }
                .padding(Theme.Metrics.space4)
                .glassCard()
        }
    }

    private func toggle(_ title: String, _ binding: Binding<Bool>) -> some View {
        Button {
            withAnimation(Theme.Motion.snappy) { binding.wrappedValue.toggle() }
        } label: {
            HStack(spacing: Theme.Metrics.space3) {
                Text(title)
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: Theme.Metrics.space3)
                switchMark(isOn: binding.wrappedValue)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func switchMark(isOn: Bool) -> some View {
        Capsule()
            .fill(isOn ? accent.opacity(0.9) : Theme.Palette.obsidian3)
            .frame(width: 42, height: 24)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(isOn ? Theme.Palette.textPrimary : Theme.Palette.textTertiary)
                    .frame(width: 18, height: 18)
                    .padding(3)
            }
            .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
    }

    /// Custom +/− stepper — layout-stable unlike macOS Stepper which propagates
    /// ideal sizes up through a ScrollView and causes a layout loop.
    private func stepperRow(_ title: String, value: Binding<Int>,
                            range: ClosedRange<Int>, step: Int, unit: String) -> some View {
        HStack(spacing: Theme.Metrics.space3) {
            Text(title)
                .font(Theme.Fonts.body(13))
                .foregroundStyle(Theme.Palette.textPrimary)
            Spacer()
            Text("\(value.wrappedValue) \(unit)")
                .font(Theme.Fonts.mono(12))
                .foregroundStyle(accent)
                .frame(minWidth: 52, alignment: .trailing)
            HStack(spacing: 2) {
                stepButton("minus", disabled: value.wrappedValue <= range.lowerBound) {
                    value.wrappedValue = max(range.lowerBound, value.wrappedValue - step)
                }
                stepButton("plus", disabled: value.wrappedValue >= range.upperBound) {
                    value.wrappedValue = min(range.upperBound, value.wrappedValue + step)
                }
            }
            .padding(3)
            .background(Capsule().fill(Theme.Palette.obsidian3))
            .overlay(Capsule().strokeBorder(Theme.Palette.hairline, lineWidth: 1))
        }
    }

    private func stepButton(_ symbol: String, disabled: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(disabled ? Theme.Palette.textTertiary : Theme.Palette.textPrimary)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
    }

    private func linkButton(_ title: String, _ urlString: String) -> some View {
        Button {
            if let url = URL(string: urlString) { NSWorkspace.shared.open(url) }
        } label: {
            Text(title).font(Theme.Fonts.title(12)).foregroundStyle(accent)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Updates

    @ViewBuilder private var updatesContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: Theme.Metrics.space3) {
                Text("Caelum \(updater.currentVersion)")
                    .font(Theme.Fonts.body(13))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer(minLength: Theme.Metrics.space3)
                Text(updateStatus)
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(updateStatusIsError ? Theme.Palette.warning : Theme.Palette.textTertiary)
                    .multilineTextAlignment(.trailing)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if let action = updateAction {
                Button(action: action.run) {
                    Text(action.title)
                        .font(Theme.Fonts.title(12))
                        .foregroundStyle(Color.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(Capsule().fill(Theme.Gradients.auroraHorizontal))
                }
                .buttonStyle(.plain)
            }
            toggle("Install updates automatically", $model.autoInstallUpdates)
            Text("Caelum checks GitHub for new releases. A new version is always offered in the panel; with automatic installs on, it's downloaded, verified and applied for you.")
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Palette.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var updateStatusIsError: Bool {
        if case .failed = updater.state { return true }
        return false
    }

    private var updateStatus: String {
        switch updater.state {
        case .idle:                  return "Not checked yet"
        case .checking:              return "Checking…"
        case .upToDate:              return "You're up to date"
        case .available(let r):      return "Version \(r.version) is available"
        case .downloading(let r):    return "Downloading \(r.version)…"
        case .installing:            return "Installing…"
        case .failed(let message, _): return message
        }
    }

    private var updateAction: (title: String, run: () -> Void)? {
        switch updater.state {
        case .idle, .upToDate:
            return ("Check for updates", { updater.checkNow() })
        case .available(let r):
            return (UpdateInstaller.canSelfInstall ? "Install \(r.version) & restart" : "Download \(r.version)",
                    { updater.install(r) })
        case .failed(_, let r):
            if let r { return ("Try again", { updater.install(r) }) }
            return ("Check again", { updater.checkNow() })
        case .checking, .downloading, .installing:
            return nil
        }
    }

    private var aboutSection: some View {
        VStack(spacing: 6) {
            Text("CAELUM")
                .font(Theme.Fonts.micro(11)).tracking(4)
                .foregroundStyle(Theme.Palette.textSecondary)
            Text("Version \(updater.currentVersion) · MIT License")
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
