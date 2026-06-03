import SwiftUI
import AppKit

/// Drives the ambient slideshow: cycles a playlist of local image files with a
/// long cross-fade, publishing a token so the view can transition.
@MainActor
final class AmbientModel: ObservableObject {
    @Published var image: NSImage?
    @Published var token = 0

    private var urls: [URL]
    private var index = 0
    private var timer: Timer?

    init(urls: [URL]) { self.urls = urls.shuffled() }

    func begin() {
        advance()
        let interval = TimeInterval(Preferences.shared.ambientIntervalSeconds)
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.advance() }
        }
    }

    func end() { timer?.invalidate(); timer = nil }

    private func advance() {
        guard !urls.isEmpty else { return }
        let url = urls[index % urls.count]
        index += 1
        let loaded = NSImage(contentsOf: url)
        withAnimation(.easeInOut(duration: 1.6)) {
            image = loaded
            token += 1
        }
    }
}

/// Full-screen "Planetarium" slideshow shown on each display during ambient mode.
struct AmbientView: View {
    @ObservedObject var model: AmbientModel
    @State private var drift = false

    var body: some View {
        ZStack {
            Color.black
            if let image = model.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(drift ? 1.12 : 1.0)
                    .animation(.easeInOut(duration: 22).repeatForever(autoreverses: true), value: drift)
                    .id(model.token)
                    .transition(.opacity)
            }
            VStack {
                Spacer()
                HStack {
                    Text("CAELUM")
                        .font(Theme.Fonts.micro(12)).tracking(5)
                        .foregroundStyle(.white.opacity(0.5))
                    Spacer()
                    Text("Move the mouse or press any key to exit")
                        .font(Theme.Fonts.body(11))
                        .foregroundStyle(.white.opacity(0.35))
                }
                .padding(44)
            }
        }
        .ignoresSafeArea()
        .onAppear { drift = true }
    }
}
