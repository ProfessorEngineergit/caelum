import AVFoundation

/// Plays a warm synthesised "bloom" chord when the wallpaper updates.
/// Generated on-the-fly — no bundled audio file needed.
@MainActor
final class WallpaperChime {
    static let shared = WallpaperChime()

    private let engine = AVAudioEngine()
    private let node   = AVAudioPlayerNode()
    private let rate   = 44_100.0
    private lazy var fmt = AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2)!

    private init() {
        engine.attach(node)
        engine.connect(node, to: engine.mainMixerNode, format: fmt)
        engine.mainMixerNode.outputVolume = 1
        try? engine.start()
    }

    func play() {
        guard engine.isRunning || (try? engine.start()) != nil else { return }
        guard let buf = makeBloom() else { return }
        node.scheduleBuffer(buf, at: nil, options: .interrupts, completionHandler: nil)
        if !node.isPlaying { node.play() }
    }

    // MARK: - Synthesis

    // A warm A-major "bloom" — raised-cosine swell into a resonant chord tail.
    // Root A2 (110 Hz) with octave + fifth. Sounds like a muted horn or a synth
    // pad hit — musical, not a system beep. Duration: 0.9 s, peak ≈ 0.25.
    private func makeBloom() -> AVAudioPCMBuffer? {
        let seconds = 0.9
        let frames  = AVAudioFrameCount(seconds * rate)
        guard let buf = AVAudioPCMBuffer(pcmFormat: fmt, frameCapacity: frames) else { return nil }
        buf.frameLength = frames
        guard let L = buf.floatChannelData?[0],
              let R = buf.floatChannelData?[1] else { return nil }

        let root = 110.0   // A2 — warm, not too low
        // A major chord: root / perfect fifth / octave / upper fifth / air
        let partials: [(mult: Double, amp: Double, detune: Double)] = [
            (1.0, 0.40,  0.00),   // 110 Hz — fundamental weight
            (1.5, 0.20, -0.18),   // 165 Hz — perfect fifth (the "dröhnen")
            (2.0, 0.24,  0.22),   // 220 Hz — octave bloom
            (3.0, 0.10, -0.12),   // 330 Hz — warmth
            (4.0, 0.06,  0.28),   // 440 Hz — air and presence
        ]
        let attack = 0.065   // raised-cosine swell
        let decay  = 4.8     // exp decay rate after swell
        var phases = [Double](repeating: 0, count: partials.count)

        for n in 0..<Int(frames) {
            let t = Double(n) / rate
            let swell = t < attack ? 0.5 - 0.5 * cos(.pi * t / attack) : 1.0
            let tail  = exp(-max(0, t - attack) * decay)
            let env   = swell * tail

            var s = 0.0
            for i in partials.indices {
                phases[i] += 2 * .pi * (root * partials[i].mult + partials[i].detune) / rate
                s += partials[i].amp * sin(phases[i])
            }
            let v = s * env * 0.28   // quiet — wallpaper change, not an event
            L[n] = Float(max(-1, min(1, v)))
            // Slight stereo width from a slow LFO phase shift
            R[n] = Float(max(-1, min(1, v * (0.96 + 0.04 * sin(2 * .pi * 0.25 * t)))))
        }
        return buf
    }
}
