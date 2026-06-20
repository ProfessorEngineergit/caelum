import SwiftUI
import AppKit

/// First-run onboarding for the menu-bar panel. Keeps the setup small enough
/// for a popover, but explicit enough that APOD's NASA key is not a mystery.
struct WelcomeView: View {
    @EnvironmentObject private var app: AppState
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var apiKey: String = Preferences.shared.usingDemoKey ? "" : Preferences.shared.nasaAPIKey

    private let accent = Theme.Palette.auroraViolet

    var body: some View {
        VStack(spacing: 0) {
            header

            VStack(spacing: Theme.Metrics.space2) {
                keyPanel

                HStack(spacing: Theme.Metrics.space2) {
                    MiniScreenshot(
                        title: "Open",
                        symbol: "cursorarrow",
                        accent: Theme.Palette.auroraCyan,
                        mode: .menuBar)
                    MiniScreenshot(
                        title: "Choose",
                        symbol: "photo.fill",
                        accent: Theme.Palette.auroraViolet,
                        mode: .sourceGrid)
                    MiniScreenshot(
                        title: "Apply",
                        symbol: "checkmark.circle.fill",
                        accent: Theme.Palette.positive,
                        mode: .wallpaper)
                }

                VStack(spacing: Theme.Metrics.space2) {
                    WelcomeStep(
                        number: "1",
                        title: "Click the Caelum icon in the menu bar.",
                        detail: "The popover opens above the desktop and keeps itself out of the Dock.")
                    WelcomeStep(
                        number: "2",
                        title: "Paste a free NASA API key for APOD.",
                        detail: "DEMO_KEY works, but a personal key avoids NASA's shared rate limit.")
                    WelcomeStep(
                        number: "3",
                        title: "Pick a source; Caelum buffers the library.",
                        detail: "When the wallpaper file is not ready yet, the action stays disabled.")
                }
            }
            .padding(.horizontal, Theme.Metrics.space5)
            .padding(.bottom, Theme.Metrics.space4)

            Spacer(minLength: 0)
            actionBar
        }
        .frame(width: Theme.Metrics.popoverWidth, height: Theme.Metrics.popoverHeight)
        .background(GlassBackground(accent: accent))
        .background(Theme.Palette.obsidian0)
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous)
                .strokeBorder(Theme.Palette.hairlineStrong, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Metrics.radiusPanel, style: .continuous))
        .environment(\.colorScheme, .dark)
    }

    private var header: some View {
        HStack(spacing: Theme.Metrics.space3) {
            ZStack {
                Circle()
                    .fill(Theme.Gradients.aurora)
                    .frame(width: 42, height: 42)
                    .shadow(color: accent.opacity(0.45), radius: 18, y: 4)
                Image(nsImage: BrandGlyph.statusImage(size: 22, dotProgress: 0.18))
                    .renderingMode(.template)
                    .foregroundStyle(Color.black)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Welcome to Caelum")
                    .font(Theme.Fonts.display(22))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                Text("A quiet menu-bar observatory for daily space wallpapers.")
                    .font(Theme.Fonts.body(11))
                    .foregroundStyle(Theme.Palette.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, Theme.Metrics.space5)
        .padding(.horizontal, Theme.Metrics.space5)
        .padding(.bottom, Theme.Metrics.space3)
    }

    private var keyPanel: some View {
        VStack(alignment: .leading, spacing: Theme.Metrics.space3) {
            HStack(spacing: Theme.Metrics.space2) {
                Image(systemName: "key.fill")
                    .foregroundStyle(accent)
                Text("NASA API key")
                    .font(Theme.Fonts.title(14))
                    .foregroundStyle(Theme.Palette.textPrimary)
                Spacer()
                Button {
                    if let url = URL(string: "https://api.nasa.gov") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Label("Get key", systemImage: "safari.fill")
                        .labelStyle(.titleAndIcon)
                        .font(Theme.Fonts.title(11))
                        .foregroundStyle(accent)
                }
                .buttonStyle(.plain)
            }

            if isSnapshot {
                Text("DEMO_KEY (bundled)")
                    .font(Theme.Fonts.mono(12))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                    .glassCard(cornerRadius: 10, fill: 0.6)
            } else {
                TextField("Paste NASA API key or leave DEMO_KEY", text: $apiKey)
                    .textFieldStyle(.plain)
                    .font(Theme.Fonts.mono(12))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .padding(10)
                    .glassCard(cornerRadius: 10, fill: 0.6)
                    .onSubmit { app.completeOnboarding(apiKey: apiKey) }
            }

            Text("Used by NASA APOD only. Hubble, Webb, ESO and curated galleries buffer separately in the background.")
                .font(Theme.Fonts.body(11))
                .foregroundStyle(Theme.Palette.textTertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Theme.Metrics.space3)
        .glassCard(fill: 0.68)
    }

    private var actionBar: some View {
        VStack(spacing: Theme.Metrics.space2) {
            Button {
                app.completeOnboarding(apiKey: apiKey)
            } label: {
                Label(apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? "Start with DEMO_KEY"
                      : "Save key & start",
                      systemImage: apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                      ? "play.fill"
                      : "checkmark.circle.fill")
            }
            .buttonStyle(AuroraPillButtonStyle())

            Button {
                app.completeOnboarding(apiKey: "")
            } label: {
                Text("Skip for now")
                    .font(Theme.Fonts.title(12))
                    .foregroundStyle(Theme.Palette.textTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, Theme.Metrics.space5)
        .padding(.top, Theme.Metrics.space2)
        .padding(.bottom, Theme.Metrics.space4)
        .background(
            Rectangle()
                .fill(Theme.Palette.obsidian0.opacity(0.58))
                .overlay(Rectangle().frame(height: 1).foregroundStyle(Theme.Palette.hairline), alignment: .top)
        )
    }
}

private struct WelcomeStep: View {
    let number: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Metrics.space3) {
            Text(number)
                .font(Theme.Fonts.mono(11))
                .foregroundStyle(Color.black)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.Gradients.auroraHorizontal))
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(Theme.Fonts.title(11.5))
                    .foregroundStyle(Theme.Palette.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(Theme.Fonts.body(9.5))
                    .foregroundStyle(Theme.Palette.textTertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .glassCard(cornerRadius: 12, fill: 0.42)
    }
}

private struct MiniScreenshot: View {
    enum Mode { case menuBar, sourceGrid, wallpaper }

    let title: String
    let symbol: String
    let accent: Color
    let mode: Mode

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(accent)
                Text(title)
                    .font(Theme.Fonts.micro(8.5))
                    .tracking(0.8)
                    .foregroundStyle(Theme.Palette.textSecondary)
                Spacer(minLength: 0)
            }

            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.Palette.obsidian0.opacity(0.75))
                preview
                    .padding(6)
            }
            .frame(height: 54)
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .strokeBorder(Theme.Palette.hairline, lineWidth: 1)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(7)
        .glassCard(cornerRadius: 12, fill: 0.45)
    }

    @ViewBuilder private var preview: some View {
        switch mode {
        case .menuBar:
            VStack(spacing: 6) {
                HStack(spacing: 5) {
                    ForEach(0..<4, id: \.self) { _ in
                        Circle().fill(Theme.Palette.textTertiary.opacity(0.28)).frame(width: 5, height: 5)
                    }
                    Spacer()
                    Circle().fill(Theme.Gradients.auroraHorizontal).frame(width: 16, height: 16)
                }
                HStack {
                    Spacer()
                    Image(systemName: "cursorarrow")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.Palette.textPrimary)
                }
            }
        case .sourceGrid:
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
                ForEach(0..<6, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(index == 1 ? AnyShapeStyle(Theme.Gradients.auroraHorizontal) : AnyShapeStyle(Theme.Palette.obsidian3))
                        .frame(height: 14)
                }
            }
        case .wallpaper:
            VStack(spacing: 5) {
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.Gradients.auroraHorizontal)
                    .frame(height: 18)
                HStack(spacing: 5) {
                    Circle().fill(Theme.Palette.obsidian3).frame(width: 11, height: 11)
                    Circle().fill(Theme.Palette.obsidian3).frame(width: 11, height: 11)
                    Circle().fill(Theme.Palette.positive.opacity(0.85)).frame(width: 11, height: 11)
                }
            }
        }
    }
}
