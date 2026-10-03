import SwiftUI

/// Slim banner at the top of the panel announcing a new Caelum release — with a
/// one-click install — and reporting download / install progress or failure.
/// Renders nothing when there's nothing to show (padding lives inside, so an
/// empty banner takes no space).
struct UpdateBanner: View {
    @ObservedObject var updater: UpdateManager

    var body: some View {
        if updater.showsBanner, let release = updater.pendingRelease {
            row(for: release)
                .padding(.horizontal, 12).padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.12)))
                .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(tint.opacity(0.3), lineWidth: 1))
                .padding(.horizontal, Theme.Metrics.space4)
                .padding(.top, Theme.Metrics.space3)
                .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    private var tint: Color {
        if case .failed = updater.state { return Theme.Palette.warning }
        return Theme.Palette.auroraViolet
    }

    @ViewBuilder
    private func row(for release: AppRelease) -> some View {
        switch updater.state {
        case .downloading:
            HStack(spacing: 8) {
                OrbitalLoader(tint: Theme.Palette.auroraViolet, size: 13)
                label("Downloading Caelum \(release.version)…")
                Spacer(minLength: 0)
            }
        case .installing:
            HStack(spacing: 8) {
                OrbitalLoader(tint: Theme.Palette.auroraViolet, size: 13)
                label("Installing — Caelum restarts in a moment…")
                Spacer(minLength: 0)
            }
        case .failed(let message, _):
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 11, weight: .bold))
                label("Update failed — \(message)", lines: 2)
                Spacer(minLength: 4)
                pill("Download") { NSWorkspace.shared.open(release.pageURL) }
                dismissButton
            }
            .foregroundStyle(Theme.Palette.warning)
        default:
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill").font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.Palette.auroraViolet)
                label("Caelum \(release.version) is available")
                Spacer(minLength: 4)
                pill(UpdateInstaller.canSelfInstall ? "Update" : "Download") { updater.install(release) }
                dismissButton
            }
        }
    }

    private func label(_ text: String, lines: Int = 1) -> some View {
        Text(text)
            .font(Theme.Fonts.body(11))
            .foregroundStyle(Theme.Palette.textSecondary)
            .lineLimit(lines).minimumScaleFactor(0.8)
            .fixedSize(horizontal: false, vertical: lines > 1)
    }

    private func pill(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(Theme.Fonts.title(11))
                .foregroundStyle(Color.black)
                .padding(.horizontal, 11).padding(.vertical, 5)
                .background(Capsule().fill(Theme.Gradients.auroraHorizontal))
        }
        .buttonStyle(.plain)
    }

    private var dismissButton: some View {
        Button { withAnimation(Theme.Motion.snappy) { updater.dismiss() } } label: {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Theme.Palette.textTertiary)
                .frame(width: 18, height: 18)
        }
        .buttonStyle(.plain)
        .help("Later")
    }
}
