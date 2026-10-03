import AVFoundation

/// Plays the intro's sound design (Resources/Sounds, rendered by
/// scripts/make-sounds.py — shared with the Windows/Linux app): one-shots that
/// may overlap (risers, impacts, a voice per source) and the ambient bed, which
/// loops gaplessly from a decoded buffer.
@MainActor
final class IntroAudio {
    private let engine = AVAudioEngine()
    private var players: [AVAudioPlayerNode] = []
    private var nextPlayer = 0
    private let bedPlayer = AVAudioPlayerNode()
    private let bedMixer = AVAudioMixerNode()
    private var buffers: [String: AVAudioPCMBuffer] = [:]
    private var fadeTimer: Timer?
    private var running = false

    func start() {
        guard !running else { return }
        let format = AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 2)!
        for _ in 0..<8 {
            let player = AVAudioPlayerNode()
            engine.attach(player)
            engine.connect(player, to: engine.mainMixerNode, format: format)
            players.append(player)
        }
        engine.attach(bedPlayer)
        engine.attach(bedMixer)
        engine.connect(bedPlayer, to: bedMixer, format: format)
        engine.connect(bedMixer, to: engine.mainMixerNode, format: format)
        bedMixer.outputVolume = 0
        do { try engine.start() } catch {
            NSLog("Caelum: intro audio unavailable: \(error.localizedDescription)")
            return
        }
        running = true
        // Decode the short sounds up front so taps play instantly.
        for name in ["step", "line"] + Self.sourceSounds.values { _ = buffer(name) }
    }

    /// Plays a sound from Resources/Sounds; overlapping sounds use separate voices.
    func play(_ name: String, volume: Float = 1) {
        guard running, let buffer = buffer(name) else { return }
        let player = players[nextPlayer]
        nextPlayer = (nextPlayer + 1) % players.count
        player.stop()
        player.volume = volume
        player.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        player.play()
    }

    /// The voice for an image source (also on a repeat tap).
    func playSource(_ id: String) {
        play("source-" + (Self.sourceSounds[id] ?? id))
    }

    static let sourceSounds: [String: String] = [
        "apod": "apod", "hubble": "hubble", "webb": "webb", "eso": "eso", "deep": "deep",
        "earth": "earth", "solar": "solar", "stations": "stations", "interstellar": "interstellar",
        "artist-impressions": "artist",
    ]

    func startBed() {
        guard running, let buffer = buffer("bed") else { return }
        bedPlayer.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
        bedPlayer.play()
        fadeBed(to: 0.9, duration: 3)
    }

    func stopBed(duration: TimeInterval = 0.8) {
        fadeBed(to: 0, duration: duration) { [weak self] in self?.bedPlayer.stop() }
    }

    func stop(after delay: TimeInterval = 0) {
        guard running else { return }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            self?.engine.stop()
            self?.running = false
        }
    }

    // MARK: - Internals

    private func buffer(_ name: String) -> AVAudioPCMBuffer? {
        if let cached = buffers[name] { return cached }
        guard let url = Bundle.main.url(forResource: name, withExtension: "m4a", subdirectory: "Sounds"),
              let file = try? AVAudioFile(forReading: url),
              let format = AVAudioFormat(standardFormatWithSampleRate: file.processingFormat.sampleRate, channels: 2),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(file.length)) else {
            return nil
        }
        do {
            if file.processingFormat == format {
                try file.read(into: buffer)
            } else {
                // e.g. a mono file: convert into the engine's stereo layout
                guard let source = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                    frameCapacity: AVAudioFrameCount(file.length)),
                      let converter = AVAudioConverter(from: file.processingFormat, to: format) else { return nil }
                try file.read(into: source)
                try converter.convert(to: buffer, from: source)
            }
        } catch {
            NSLog("Caelum: couldn't read sound \(name): \(error.localizedDescription)")
            return nil
        }
        buffers[name] = buffer
        return buffer
    }

    private func fadeBed(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let from = bedMixer.outputVolume
        let started = Date()
        fadeTimer = Timer.scheduledTimer(withTimeInterval: 1.0 / 30.0, repeats: true) { [weak self] timer in
            MainActor.assumeIsolated {
                guard let self else { timer.invalidate(); return }
                let k = Float(min(1, Date().timeIntervalSince(started) / duration))
                self.bedMixer.outputVolume = from + (target - from) * k
                if k >= 1 {
                    timer.invalidate()
                    completion?()
                }
            }
        }
    }
}
