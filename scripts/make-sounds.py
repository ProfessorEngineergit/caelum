#!/usr/bin/env python3
"""Renders Caelum's sound design into Resources/Sounds/*.m4a (shared by the macOS
and the Windows/Linux app). Everything is synthesised offline — band-limited
oscillators, Karplus–Strong plucks, FM bells, a convolution hall — then encoded
with ffmpeg. Requires numpy + scipy + pyloudnorm + ffmpeg.

    python3 scripts/make-sounds.py

Sounds
  intro.m4a        riser that builds for 4.4 s and lands on a deep impact (the flash)
  outro.m4a        the shorter, bigger jump when setup finishes (impact at 1.6 s)
  bed.m4a          seamless 32 s ambient loop under the setup — steady, no swells
  update.m4a       the update screen: jump in, then a rising fanfare
  line.m4a         an accent for each change line on the update screen
  step.m4a         soft whoosh for moving between setup steps
  source-*.m4a     one distinct voice per image source, all in A major
"""
import pathlib
import subprocess
import tempfile

import numpy as np
from scipy import signal

SR = 48_000
ROOT = pathlib.Path(__file__).resolve().parents[1]
OUT = ROOT / "Resources" / "Sounds"
rng = np.random.default_rng(7)


def hz(note):
    """'A4' / 'C#5' → frequency."""
    names = {"C": -9, "C#": -8, "D": -7, "D#": -6, "E": -5, "F": -4, "F#": -3,
             "G": -2, "G#": -1, "A": 0, "A#": 1, "B": 2}
    name, octave = note[:-1], int(note[-1])
    return 440.0 * 2 ** ((names[name] + 12 * (octave - 4)) / 12)


def t_axis(seconds):
    return np.arange(int(seconds * SR)) / SR


def env_adsr(n, attack, decay_tau, release=0.0):
    """Linear-in-dB style: smooth raised-cosine attack, exponential decay."""
    t = np.arange(n) / SR
    a = np.clip(t / max(attack, 1e-4), 0, 1)
    a = 0.5 - 0.5 * np.cos(np.pi * a)
    d = np.exp(-np.maximum(t - attack, 0) / decay_tau)
    e = a * d
    if release > 0:
        r = int(release * SR)
        e[-r:] *= np.linspace(1, 0, r) ** 2
    return e


def saw_bl(freq, seconds, phase=0.0):
    """Band-limited sawtooth by additive synthesis (harmonics below 18 kHz)."""
    t = t_axis(seconds)
    f = np.broadcast_to(freq, t.shape) if np.ndim(freq) else np.full(t.shape, freq)
    ph = 2 * np.pi * np.cumsum(f) / SR + phase
    out = np.zeros_like(t)
    nmax = int(18000 / np.max(f))
    for k in range(1, nmax + 1):
        # fade harmonics that would alias as the pitch rises
        fade = np.clip((18000 - k * f) / 2000, 0, 1)
        out += fade * np.sin(k * ph) / k
    return out * (2 / np.pi)


def supersaw(freq, seconds, voices=7, detune_cents=14):
    out = np.zeros(int(seconds * SR))
    spread = np.linspace(-1, 1, voices)
    for s in spread:
        f = freq * 2 ** (s * detune_cents / 1200)
        out += saw_bl(f, seconds, phase=rng.uniform(0, 2 * np.pi))
    return out / np.sqrt(voices)


def lowpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "low", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def highpass(x, cutoff, order=2):
    sos = signal.butter(order, cutoff, "high", fs=SR, output="sos")
    return signal.sosfilt(sos, x)


def sweep_filter(x, cutoffs, kind="low", block=256, q=0.9):
    """Time-varying state-variable filter (cutoff per sample)."""
    out = np.zeros_like(x)
    low = band = 0.0
    damp = 1 / q
    for i in range(0, len(x), block):
        fc = float(np.clip(cutoffs[min(i, len(cutoffs) - 1)], 20, SR * 0.45))
        f = 2 * np.sin(np.pi * fc / SR)
        seg = x[i:i + block]
        res = np.empty_like(seg)
        for j, v in enumerate(seg):
            low += f * band
            high = v - low - damp * band
            band += f * high
            res[j] = low if kind == "low" else (band if kind == "band" else high)
        out[i:i + block] = res
    return out


def hall_ir(seconds=3.6, predelay=0.025, bright=0.55):
    """Stereo hall impulse response: decorrelated noise, exponential decay,
    damping that darkens the tail, a few early reflections."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    ir = np.zeros((n, 2))
    for ch in range(2):
        noise = rng.standard_normal(n)
        decay = np.exp(-6.9 * t / seconds)                 # -60 dB at `seconds`
        # darker over time: blend a lowpassed copy in as the tail ages
        dark = lowpass(noise, 1800, 2)
        mix = np.clip(t / (seconds * 0.6), 0, 1) ** 0.7
        tail = (noise * bright * (1 - mix) + dark * mix) * decay
        ir[:, ch] = tail
        for k in range(6):                                  # early reflections
            d = int((predelay + rng.uniform(0.004, 0.06)) * SR)
            ir[d, ch] += rng.uniform(0.3, 0.7) * (1 if rng.random() > 0.5 else -1)
    pd = int(predelay * SR)
    ir = np.vstack([np.zeros((pd, 2)), ir])
    return ir / np.sqrt(np.sum(ir ** 2) / 2)


def reverb(stereo, wet=0.3, ir=None, circular=False):
    ir = hall_ir() if ir is None else ir
    out = np.zeros((len(stereo) + (0 if circular else len(ir) - 1), 2))
    for ch in range(2):
        if circular:   # loop-safe: the tail wraps into the start
            n = len(stereo)
            ir_c = np.zeros(n)
            m = min(n, len(ir))
            ir_c[:m] = ir[:m, ch]
            out[:, ch] = np.fft.irfft(np.fft.rfft(stereo[:, ch]) * np.fft.rfft(ir_c), n)
        else:
            out[:, ch] = signal.fftconvolve(stereo[:, ch], ir[:, ch])
    dry = np.zeros_like(out)
    dry[:len(stereo)] = stereo
    return dry * (1 - wet) + out * wet * 0.35


def stereo(mono, width=0.0, pan=0.0):
    """Mono → stereo; `width` adds a short Haas offset, `pan` −1…1."""
    left, right = mono.copy(), mono.copy()
    if width > 0:
        d = int(width * 0.012 * SR)
        right = np.concatenate([np.zeros(d), mono])[:len(mono)]
    gl, gr = np.cos((pan + 1) * np.pi / 4), np.sin((pan + 1) * np.pi / 4)
    return np.stack([left * gl * 1.414, right * gr * 1.414], axis=1)


def pad_to(x, n):
    if len(x) >= n:
        return x[:n]
    return np.vstack([x, np.zeros((n - len(x), x.shape[1]))]) if x.ndim == 2 else np.concatenate([x, np.zeros(n - len(x))])


def place(dst, src, at):
    i = int(at * SR)
    end = min(len(dst), i + len(src))
    dst[i:end] += src[:end - i]


def master(x, peak_db=-1.0, drive=1.0):
    """Gentle saturation + peak normalisation; fades the very ends."""
    x = x - np.mean(x, axis=0)
    if drive != 1.0:
        x = np.tanh(x * drive) / np.tanh(drive)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * 10 ** (peak_db / 20)
    f = int(0.004 * SR)
    x[:f] *= np.linspace(0, 1, f)[:, None]
    x[-f * 10:] *= np.linspace(1, 0, f * 10)[:, None]
    return x


# Loudness targets (integrated LUFS) — the jumps are loud on purpose, the
# interface sits below them, the bed well underneath the setup.
LOUDNESS = {"intro": -14.0, "outro": -14.0, "update": -15.0, "bed": -27.0, "step": -22.0, "line": -21.0}
TRUE_PEAK_DB = -1.5


def loudness_and_peak(name, x):
    """Scale to the target loudness, then pull down further if the 4×-oversampled
    (true) peak would exceed TRUE_PEAK_DB — so AAC never clips."""
    import pyloudnorm
    target = LOUDNESS.get(name, -19.0)
    measured = pyloudnorm.Meter(SR).integrated_loudness(x)
    x = x * 10 ** ((target - measured) / 20)
    true_peak = np.max(np.abs(signal.resample_poly(x, 4, 1, axis=0)))
    limit = 10 ** (TRUE_PEAK_DB / 20)
    if true_peak > limit:
        x = x * limit / true_peak
    return x


def write(name, x, bitrate="256k"):
    OUT.mkdir(parents=True, exist_ok=True)
    x = loudness_and_peak(name, x)
    pcm = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with tempfile.NamedTemporaryFile(suffix=".raw") as raw:
        raw.write(pcm.tobytes())
        raw.flush()
        subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-f", "s16le", "-ar", str(SR), "-ac", "2",
                        "-i", raw.name, "-c:a", "aac", "-b:a", bitrate, "-movflags", "+faststart",
                        str(OUT / f"{name}.m4a")], check=True)
    print(f"{name}.m4a  {len(x) / SR:5.2f}s")


# MARK: - Building blocks of the jump

def riser(seconds, top=9000.0):
    """Noise wash + gliding supersaw stack + accelerating flutter, all building."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    p = t / seconds
    curve = p ** 2.2                                           # slow start, steep end

    noise = rng.standard_normal(n)
    wash = sweep_filter(noise, 250 + (top - 250) * curve, "band", q=1.6) * (0.15 + 0.85 * curve)

    f0 = hz("A1") * 2 ** (2.0 * curve)                         # two octaves up
    tone = np.zeros(n)
    for mult in (1, 1.5, 2, 3):
        tone += supersaw(f0 * mult, seconds, voices=5, detune_cents=12 + 18 * mult) / mult
    tone = sweep_filter(tone, 300 + 6000 * curve, "low", q=1.1) * curve ** 1.3

    flutter_rate = 3 + 26 * curve
    flutter = 0.75 + 0.25 * np.sin(2 * np.pi * np.cumsum(flutter_rate) / SR)

    mono = (wash * 0.9 + tone * 0.7) * flutter
    mono *= np.clip((seconds - t) / 0.03, 0, 1)                # tight cut right before the hit
    return stereo(mono, width=0.8)


def impact(seconds=6.0, size=1.0):
    """Sub drop + crack + detuned 'braam' + shimmer — the BÄFF."""
    n = int(seconds * SR)
    t = np.arange(n) / SR

    # sub: pitch dive 110 → 32 Hz
    f = 32 + 78 * np.exp(-t / 0.09)
    sub = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / (0.9 * size))
    sub = np.tanh(sub * 1.6)

    crack = highpass(rng.standard_normal(n), 1800) * np.exp(-t / 0.035)
    thump = lowpass(rng.standard_normal(n), 220) * np.exp(-t / 0.12) * 3

    braam = np.zeros(n)
    for note, g in (("A1", 1.0), ("E2", 0.8), ("A2", 0.7), ("C#3", 0.35)):
        braam += supersaw(hz(note), seconds, voices=7, detune_cents=22) * g
    cutoff = 180 + 3200 * np.exp(-t / 0.5) + 400 * np.exp(-t / 2.5)
    braam = sweep_filter(braam, cutoff, "low", q=1.3)
    braam = np.tanh(braam * 1.8) * env_adsr(n, 0.008, 1.6 * size)

    shimmer = np.zeros(n)
    for note, g in (("A5", 0.5), ("E6", 0.35), ("C#7", 0.2), ("A7", 0.1)):
        shimmer += np.sin(2 * np.pi * hz(note) * t + rng.uniform(0, 6)) * g
    shimmer *= env_adsr(n, 0.05, 2.2) * (1 + 0.15 * np.sin(2 * np.pi * 5.1 * t))

    low = stereo(sub * 1.1 + thump * 0.6)
    mid = stereo(braam * 0.75 + crack * 0.35, width=1.0)
    high = stereo(shimmer * 0.12, width=1.0)
    return low + reverb(mid + high, wet=0.45 * size, ir=hall_ir(4.5))[:n]


def make_intro():
    flash = 4.4
    total = flash + 7.0
    x = np.zeros((int(total * SR), 2))
    place(x, riser(flash - 0.3), 0.3)
    # reverse-reverb suck into the hit
    swell = reverb(stereo(highpass(rng.standard_normal(int(0.9 * SR)), 900) * env_adsr(int(0.9 * SR), 0.003, 0.05)),
                   wet=1.0, ir=hall_ir(1.2))[::-1][:int(1.1 * SR)]
    place(x, swell * 0.5, flash - 1.1)
    place(x, impact(6.5, size=1.0), flash)
    write("intro", master(x, drive=1.2))


def tom(freq, seconds=0.8, gain=1.0):
    """Synth tom/taiko: pitched sine with a dive, plus a skin of filtered noise."""
    n = int(seconds * SR)
    t = np.arange(n) / SR
    f = freq * (1 + 0.6 * np.exp(-t / 0.03))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.28)
    skin = lowpass(rng.standard_normal(n), 900) * np.exp(-t / 0.05)
    return np.tanh((body + skin * 0.5) * 2.0) * gain


OUTRO_HIT = 5.5     # the flash; WarpView.exitFlash and the desktop app use the same time


def make_outro():
    """A short trailer cue: pulsing ostinato and accelerating drums under a
    building string-like swell, a braam at the start, the biggest hit on the
    flash, then a wide A-major resolve as the new wallpaper appears."""
    hit = OUTRO_HIT
    total = hit + 6.5
    n = int(total * SR)
    x = np.zeros((n, 2))

    # opening braam as the panel collapses into light
    place(x, impact(4.0, size=0.8) * 0.55, 0.45)

    # ostinato: A1 eighths, getting faster and brighter
    t_beat, beat = 0.9, 0.42
    while t_beat < hit - 0.1:
        k = (t_beat - 0.9) / (hit - 0.9)
        note = supersaw(hz("A1") * (2 if int(t_beat / beat) % 4 == 3 else 1), 0.35, voices=5, detune_cents=10)
        note = lowpass(note, 400 + 2600 * k) * env_adsr(len(note), 0.005, 0.12)
        place(x, stereo(note * (0.25 + 0.35 * k), width=0.5), t_beat)
        t_beat += beat
        beat = max(0.11, beat * 0.93)

    # drums: half-time toms that double up toward the hit
    t_drum, gap = 0.9, 0.84
    i = 0
    while t_drum < hit - 0.05:
        k = (t_drum - 0.9) / (hit - 0.9)
        place(x, stereo(tom(hz("A1") * (1.0 if i % 2 == 0 else 1.5), gain=0.5 + 0.5 * k), pan=0.25 * (-1) ** i), t_drum)
        t_drum += gap
        gap = max(0.13, gap * 0.86)
        i += 1

    # string-like swell: A minor → A major lift, opening filter
    swell_len = hit - 0.9
    m = int(swell_len * SR)
    tt = np.arange(m) / SR
    chord = np.zeros(m)
    for note, g in (("A2", 1.0), ("E3", 0.8), ("A3", 0.7), ("C4", 0.5), ("E4", 0.45)):
        chord += supersaw(hz(note), swell_len, voices=7, detune_cents=16) * g
    chord = sweep_filter(chord, 300 + 4200 * (tt / swell_len) ** 2, "low", q=1.0)
    chord *= (tt / swell_len) ** 1.6
    place(x, reverb(stereo(chord * 0.45, width=1.0), wet=0.4, ir=hall_ir(2.5))[:m], 0.9)
    place(x, riser(hit - 1.6, top=12000) * 0.9, 1.6)

    # the flash: biggest hit + a second wide layer
    place(x, impact(6.5, size=1.4), hit)
    place(x, impact(4.0, size=0.6) * 0.35, hit + 0.16)

    # resolve: A major, bright, wide, with bells — the new wallpaper arrives
    rl = total - hit
    r = int(rl * SR)
    tr = np.arange(r) / SR
    major = np.zeros(r)
    for note, g in (("A2", 0.8), ("E3", 0.7), ("A3", 0.7), ("C#4", 0.6), ("E4", 0.5), ("A4", 0.35)):
        major += supersaw(hz(note), rl, voices=7, detune_cents=14) * g
    major = lowpass(major, 3200) * env_adsr(r, 0.35, 3.0, release=1.0)
    bells = np.zeros(r)
    for i, note in enumerate(("A5", "C#6", "E6", "A6")):
        b = fm_bell(hz(note), rl - 0.2 * i, 3.5, 1.4, 1.8)
        bells[int(0.2 * i * SR):int(0.2 * i * SR) + len(b)] += b * 0.3
    place(x, reverb(stereo(major * 0.4, width=1.0) + stereo(bells, width=0.6), wet=0.5, ir=hall_ir(4.0))[:r], hit + 0.25)

    write("outro", master(x, drive=1.25))


def make_update():
    """The update screen: the intro's jump (riser into an impact at 4.4 s), then a
    rising three-note fanfare as the version number lands, and 'line' accents
    the screen plays as each change appears."""
    flash = 4.4
    total = flash + 6.0
    x = np.zeros((int(total * SR), 2))
    place(x, riser(flash - 0.3) * 0.9, 0.3)
    place(x, impact(5.5, size=0.9), flash)
    for i, note in enumerate(("A4", "C#5", "E5", "A5")):
        b = fm_bell(hz(note), 3.0, 3.5, 1.6, 1.6)
        place(x, reverb(stereo(b * 0.5, width=0.6, pan=-0.3 + 0.2 * i), wet=0.4, ir=hall_ir(2.5))[:int(3.5 * SR)], flash + 0.55 + 0.16 * i)
    write("update", master(x, drive=1.15))
    # one accent per change line: a low pulse with a glassy tick
    n = int(1.6 * SR)
    t = np.arange(n) / SR
    pulse = np.sin(2 * np.pi * 55 * t) * np.exp(-t / 0.18) * 0.8
    tick = partials(hz("E6"), 1.6, [1, 2.76], [0.6, 0.2], [0.25, 0.08])
    write("line", master(reverb(stereo(pulse) + stereo(tick * 0.5, width=0.5), wet=0.35, ir=hall_ir(1.8))[:n], peak_db=-6))


# MARK: - The bed

def make_bed(seconds=32.0):
    """Seamless loop: every oscillator completes whole cycles in `seconds`, every
    modulation is periodic in `seconds`, and the hall wraps circularly."""
    n = int(seconds * SR)
    t = np.arange(n) / SR

    def loop_hz(f):           # nearest frequency with whole cycles in the loop
        return round(f * seconds) / seconds

    voices = np.zeros(n)
    # Detuning makes voices beat — in the bass that's an audible pulse ("comes and
    # goes"), so low notes get a single voice and the rest only a hair of chorus.
    for note, g in (("A2", 1.0), ("E3", 0.8), ("A3", 0.6), ("B3", 0.35), ("C#4", 0.45), ("E4", 0.3)):
        detunes = (0,) if hz(note) < 200 else (-1.5, 0, 1.8)
        for d in detunes:                                        # cents
            f = loop_hz(hz(note) * 2 ** (d / 1200))
            ph = rng.uniform(0, 2 * np.pi)
            k_max = int(5000 / f)
            for k in range(1, k_max + 1):                        # band-limited saw, darkened
                voices += g * np.sin(2 * np.pi * loop_hz(k * f) * t + k * ph) / (k ** 1.35) / len(detunes)
    # very slow, shallow filter drift (one cycle per loop) — no audible swells
    drift = 0.5 + 0.5 * np.sin(2 * np.pi * t / seconds)
    bright = lowpass(voices, 1400)
    dark = lowpass(voices, 700)
    pad = dark * (1 - 0.35 * drift) + bright * 0.35 * drift

    air = np.zeros(n)
    noise = rng.standard_normal(n)
    air = signal.sosfiltfilt(signal.butter(2, [2500, 7000], "band", fs=SR, output="sos"), noise) * 0.03

    left = pad + air
    right = np.roll(pad, int(0.011 * SR)) + np.roll(air, 977)
    x = np.stack([left, right], axis=1)
    x = reverb(x, wet=0.55, ir=hall_ir(5.0, bright=0.4), circular=True)
    x = x - np.mean(x, axis=0)
    x = x / np.max(np.abs(x)) * 10 ** (-6 / 20)                 # quiet bed, no fades: it loops
    write("bed", x, bitrate="192k")


# MARK: - Interface

def make_step():
    n = int(0.9 * SR)
    t = np.arange(n) / SR
    noise = rng.standard_normal(n)
    whoosh = sweep_filter(noise, 600 + 5000 * np.sin(np.pi * np.clip(t / 0.45, 0, 1)), "band", q=2.0)
    whoosh *= np.sin(np.pi * np.clip(t / 0.45, 0, 1)) ** 2 * 0.6
    tick = np.sin(2 * np.pi * hz("E6") * t) * np.exp(-t / 0.05) * 0.25
    write("step", master(reverb(stereo(whoosh, width=0.6) + stereo(tick), wet=0.35, ir=hall_ir(1.6))[:int(1.8 * SR)], peak_db=-6))


def karplus(freq, seconds, damping=0.996, brightness=0.6):
    n = int(seconds * SR)
    period = int(SR / freq)
    buf = lowpass(rng.uniform(-1, 1, period), 2000 + 9000 * brightness, 1)
    out = np.zeros(n)
    idx = 0
    for i in range(n):
        v = buf[idx]
        nxt = buf[(idx + 1) % period]
        buf[idx] = damping * 0.5 * (v + nxt)
        out[i] = v
        idx = (idx + 1) % period
    return out


def fm_bell(freq, seconds, ratio=3.5, index=3.0, tau=1.6):
    t = t_axis(seconds)
    mod_env = np.exp(-t / (tau * 0.35))
    car = np.sin(2 * np.pi * freq * t + index * mod_env * np.sin(2 * np.pi * freq * ratio * t))
    return car * env_adsr(len(t), 0.002, tau)


def partials(freq, seconds, ratios, gains, taus, attack=0.002):
    t = t_axis(seconds)
    out = np.zeros(len(t))
    for r, g, tau in zip(ratios, gains, taus):
        out += g * np.sin(2 * np.pi * freq * r * t + rng.uniform(0, 6)) * np.exp(-t / tau)
    a = np.clip(t / attack, 0, 1)
    return out * a


def source_sound(kind):
    L = 3.2
    n = int(L * SR)
    x = np.zeros((n, 2))

    def add(mono, at=0.0, pan=0.0, gain=1.0, width=0.3):
        place(x, stereo(pad_to(mono, n - int(at * SR)) * gain, width=width, pan=pan), at)

    if kind == "apod":            # bright FM bell + octave sparkle
        add(fm_bell(hz("A5"), L, 3.5, 2.4, 1.4))
        add(fm_bell(hz("E6"), L, 2.0, 1.2, 0.9), at=0.06, pan=0.3, gain=0.45)
        add(partials(hz("A2"), L, [1], [1], [0.6]), gain=0.25)
    elif kind == "hubble":        # glass marimba dyad
        for i, note in enumerate(("E5", "A5")):
            add(partials(hz(note), L, [1, 4, 9.2], [1, 0.35, 0.08], [0.55, 0.12, 0.05]), at=i * 0.07, pan=-0.3 + 0.6 * i)
    elif kind == "webb":          # warm golden pluck, rising third
        add(karplus(hz("C#5"), L, 0.997, 0.4), pan=-0.25)
        add(karplus(hz("E5"), L, 0.997, 0.4), at=0.11, pan=0.25)
        add(partials(hz("A3"), L, [1, 2], [0.5, 0.2], [1.2, 0.6], attack=0.01), gain=0.4)
    elif kind == "eso":           # deep temple bell from the mountains
        add(partials(hz("A3"), L, [0.5, 1, 2.76, 5.4, 8.93], [0.5, 1, 0.5, 0.25, 0.12], [2.6, 2.0, 1.2, 0.6, 0.3]), gain=0.9)
    elif kind == "deep":          # airy swell, distant
        tone = supersaw(hz("B4"), L, voices=5, detune_cents=18) + supersaw(hz("E5"), L, voices=5, detune_cents=18) * 0.6
        add(lowpass(tone, 2200) * env_adsr(n, 0.25, 0.9), gain=0.35, width=1.0)
    elif kind == "earth":         # kalimba, two tines
        for i, note in enumerate(("A4", "E5")):
            add(partials(hz(note), L, [1, 5.4], [1, 0.25], [0.7, 0.06]), at=i * 0.12, pan=-0.2 + 0.4 * i)
    elif kind == "solar":         # harp arpeggio
        for i, note in enumerate(("A4", "C#5", "E5", "A5")):
            add(karplus(hz(note), L, 0.998, 0.75), at=i * 0.065, pan=-0.45 + 0.3 * i, gain=0.8)
    elif kind == "stations":      # spacecraft comm chirps
        t = t_axis(0.09)
        for i, note in enumerate(("E6", "A6", "E6")):
            chirp = signal.square(2 * np.pi * hz(note) * t, duty=0.3) * env_adsr(len(t), 0.003, 0.05)
            add(lowpass(chirp, 5000), at=i * 0.11, gain=0.35, pan=(-0.3, 0.3, 0)[i])
        add(partials(hz("A3"), L, [1], [1], [0.4]), gain=0.25)
    elif kind == "interstellar":  # cathedral organ chord
        t = t_axis(L)
        organ = np.zeros(n)
        for note in ("A3", "E4", "A4", "C#5"):
            for k, g in ((1, 1), (2, 0.5), (3, 0.3), (4, 0.25), (6, 0.12), (8, 0.08)):
                organ += g * np.sin(2 * np.pi * hz(note) * k * t)
        add(organ * env_adsr(n, 0.12, 1.1) * 0.12, width=1.0)
    elif kind == "artist":        # glittering upward glissando
        for i in range(9):
            note = ["A5", "B5", "C#6", "E6", "F#6", "A6", "B6", "C#7", "E7"][i]
            add(partials(hz(note), L, [1, 3], [1, 0.2], [0.35, 0.08]), at=i * 0.035, pan=-0.6 + 0.15 * i, gain=0.4)
    # no rumble, and every voice ends with a fade instead of a cut
    x = highpass(x.T, 70, 2).T
    fade = int(0.6 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
    return master(reverb(x, wet=0.38, ir=hall_ir(2.8))[:int(4.6 * SR)], peak_db=-4)


if __name__ == "__main__":
    import sys
    only = set(sys.argv[1:])            # e.g. `make-sounds.py bed sources`; nothing = all
    if not only or "intro" in only: make_intro()
    if not only or "outro" in only: make_outro()
    if not only or "update" in only: make_update()
    if not only or "bed" in only: make_bed()
    if not only or "step" in only: make_step()
    if not only or "sources" in only:
        for kind in ("apod", "hubble", "webb", "eso", "deep", "earth", "solar", "stations", "interstellar", "artist"):
            write(f"source-{kind}", source_sound(kind))
