import AVFoundation

/// A tiny synthesized soundscape for the cinematic onboarding — a soft, evolving
/// ambient pad plus a glassy chime, generated on the fly (no bundled audio).
/// Arc-style: the first thing you hear makes the moment feel special.
@MainActor
final class OnboardingAudio {
    private let engine = AVAudioEngine()
    private let pad = AVAudioPlayerNode()
    private let chimeNode = AVAudioPlayerNode()
    private let sampleRate = 44_100.0
    private var format: AVAudioFormat { AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2)! }
    private var fadeTimer: Timer?
    private var running = false

    func start() {
        guard !running else { return }
        engine.attach(pad)
        engine.attach(chimeNode)
        engine.connect(pad, to: engine.mainMixerNode, format: format)
        engine.connect(chimeNode, to: engine.mainMixerNode, format: format)
        engine.mainMixerNode.outputVolume = 0
        do { try engine.start() } catch { return }
        running = true

        if let buffer = makePad() {
            pad.scheduleBuffer(buffer, at: nil, options: .loops, completionHandler: nil)
            pad.play()
        }
        fade(to: 0.42, duration: 3.5)
        // Signature opening chime.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in self?.chime(soft: false) }
    }

    func chime(soft: Bool = true) {
        guard running, let buffer = makeChime(soft: soft) else { return }
        chimeNode.scheduleBuffer(buffer, at: nil, options: .interrupts, completionHandler: nil)
        if !chimeNode.isPlaying { chimeNode.play() }
    }

    func stop() {
        guard running else { return }
        fade(to: 0, duration: 1.2) { [weak self] in
            self?.engine.stop()
            self?.running = false
        }
    }

    // MARK: - Volume fades

    private func fade(to target: Float, duration: TimeInterval, completion: (() -> Void)? = nil) {
        fadeTimer?.invalidate()
        let start = engine.mainMixerNode.outputVolume
        let steps = 60
        let dt = duration / Double(steps)
        var i = 0
        fadeTimer = Timer.scheduledTimer(withTimeInterval: dt, repeats: true) { [weak self] timer in
            i += 1
            let t = Float(i) / Float(steps)
            self?.engine.mainMixerNode.outputVolume = start + (target - start) * t
            if i >= steps { timer.invalidate(); completion?() }
        }
    }

    // MARK: - Synthesis

    /// A warm A-major pad (A2/E3/A3/C#4) with gentle detune and a slow breathing LFO.
    private func makePad() -> AVAudioPCMBuffer? {
        let seconds = 12.0
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let partials: [(freq: Double, amp: Double, detune: Double)] = [
            (110.00, 0.16, 0.0), (164.81, 0.12, 0.4), (220.00, 0.10, -0.5),
            (277.18, 0.08, 0.6), (329.63, 0.05, -0.3),
        ]
        guard let L = buffer.floatChannelData?[0], let R = buffer.floatChannelData?[1] else { return nil }
        for n in 0..<Int(frames) {
            let t = Double(n) / sampleRate
            let lfo = 0.78 + 0.22 * sin(2 * .pi * 0.08 * t)           // slow breathing
            // Long fade-in / fade-out at the loop boundary so it loops seamlessly.
            let envIn = min(1.0, t / 3.0)
            let envOut = min(1.0, (seconds - t) / 3.0)
            let env = min(envIn, envOut) * lfo
            var s = 0.0
            for p in partials { s += p.amp * sin(2 * .pi * (p.freq + p.detune) * t) }
            let v = Float(s * env * 0.5)
            L[n] = v
            R[n] = Float(s * env * 0.5 * (0.95 + 0.05 * sin(2 * .pi * 0.05 * t)))  // subtle width
        }
        return buffer
    }

    /// A glassy bell — fundamental plus inharmonic partials with exponential decay.
    private func makeChime(soft: Bool) -> AVAudioPCMBuffer? {
        let seconds = soft ? 1.4 : 2.4
        let frames = AVAudioFrameCount(seconds * sampleRate)
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frames) else { return nil }
        buffer.frameLength = frames
        let base = soft ? 659.25 : 440.0   // E5 for transitions, A4 for the opener
        let partials: [(mult: Double, amp: Double, decay: Double)] = [
            (1.0, 0.5, 2.2), (2.01, 0.28, 2.8), (3.0, 0.16, 3.4), (4.7, 0.08, 4.2),
        ]
        guard let L = buffer.floatChannelData?[0], let R = buffer.floatChannelData?[1] else { return nil }
        let peak: Float = soft ? 0.18 : 0.3
        for n in 0..<Int(frames) {
            let t = Double(n) / sampleRate
            var s = 0.0
            for p in partials { s += p.amp * sin(2 * .pi * base * p.mult * t) * exp(-t * p.decay) }
            let v = Float(s) * peak
            L[n] = v; R[n] = v
        }
        return buffer
    }
}
