#!/usr/bin/env python3
"""Monolith's sound effects, synthesised (no recordings, nothing borrowed): 16-bit stereo WAVs at
48 kHz written into shell/sounds/<pack>/<event>.wav, and the notification tones into
shell/sounds/notify/<tone>.wav. Plain Python, no NumPy: run it again after changing a recipe
(it takes a minute).

Every pack plays the same score (SCORE: what happens in each event, in notes, taps, slides and
air) on its own instrument, built from a few real techniques instead of bare waveforms:
  modal synthesis   a struck object rings at its own (inharmonic) partials, each dying away at its
                    own rate: wood (woodblock, marimba bar), glass (a wine glass), the soft pack's
                    felt-mallet tones
  excitation        the strike itself: a few milliseconds of filtered noise (a mallet, a fingertip)
  filters           RBJ biquads (band-pass, low-pass, high-pass), swept for air and synth sounds
  band-limited      saws by polyBLEP and squares built from their harmonics, so nothing aliases
                    (the old packs' square waves did: the "8-bit" fizz)
  space             a small stereo Schroeder room per pack, and a touch of width

  soft   felt ticks and warm, round tones (a sine with a quick second harmonic)
  glass  wine-glass partials (1 : 2.32 : 4.25 : 6.63) that ring on, a bright tink on the strike
  pop    bubbles: the pitch rises as each one closes, like a real one
  wood   a woodblock knock (1 : 2.57 : 4.2, gone in 50 ms) and marimba bars (1 : 4 : 10)
"""
import math
import os
import random
import struct
import wave

RATE = 48000
NYQ = RATE / 2
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "sounds")
TAU = 2 * math.pi


def note(name):
    """'A4' -> 440 Hz ('C#5', 'Eb4' too)"""
    names = {"C": -9, "D": -7, "E": -5, "F": -4, "G": -2, "A": 0, "B": 2}
    n = names[name[0]]
    rest = name[1:]
    if rest[0] in "#b":
        n += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return 440.0 * 2 ** ((n + (int(rest) - 4) * 12) / 12)


# ── building blocks ─────────────────────────────────────────────────────────────────────────────

def silence(sec):
    return [0.0] * max(1, int(sec * RATE))


def mix_into(buf, src, at=0.0, gain=1.0):
    i0 = int(at * RATE)
    need = i0 + len(src)
    if need > len(buf):
        buf.extend([0.0] * (need - len(buf)))
    for i, v in enumerate(src):
        buf[i0 + i] += v * gain
    return buf


def noise(n, rng):
    return [rng.random() * 2 - 1 for _ in range(n)]


def biquad(x, kind, f, q=0.707):
    """RBJ cookbook filter: lp, hp, bp (constant 0 dB peak)"""
    f = min(f, NYQ * 0.95)
    w = TAU * f / RATE
    cw, sw = math.cos(w), math.sin(w)
    a = sw / (2 * q)
    if kind == "lp":
        b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
    elif kind == "hp":
        b0, b1, b2 = (1 + cw) / 2, -(1 + cw), (1 + cw) / 2
    else:
        b0, b1, b2 = a, 0.0, -a
    a0, a1, a2 = 1 + a, -2 * cw, 1 - a
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    for i, v in enumerate(x):
        o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, v, y1, o
        y[i] = o
    return y


def sweep_filter(x, kind, f0, f1, q=0.707, block=64):
    """a filter whose cutoff glides (exponentially) from f0 to f1 across x, a block at a time"""
    y = [0.0] * len(x)
    x1 = x2 = y1 = y2 = 0.0
    n = len(x)
    for start in range(0, n, block):
        f = f0 * (f1 / f0) ** (start / max(1, n))
        f = min(f, NYQ * 0.95)
        w = TAU * f / RATE
        cw, sw = math.cos(w), math.sin(w)
        a = sw / (2 * q)
        if kind == "lp":
            b0, b1, b2 = (1 - cw) / 2, 1 - cw, (1 - cw) / 2
        else:
            b0, b1, b2 = a, 0.0, -a
        a0, a1, a2 = 1 + a, -2 * cw, 1 - a
        b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, a1 / a0, a2 / a0
        for i in range(start, min(n, start + block)):
            v = x[i]
            o = b0 * v + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
            x2, x1, y2, y1 = x1, v, y1, o
            y[i] = o
    return y


def modal(freq, ratios, amps, decays, dur, glide=1.0, attack=0.0015, rng=None):
    """a struck object: decaying sine partials at freq × ratios (ones past the audible range are
    left out), each with its own decay time (s, to -60 dB), a slight random phase"""
    n = int(dur * RATE)
    out = [0.0] * n
    rng = rng or random.Random(1)
    for r, a, d in zip(ratios, amps, decays):
        f = freq * r
        if f * max(1.0, glide) > NYQ * 0.9 or a <= 0:
            continue
        k = math.exp(-6.9 / (d * RATE))          # per sample, -60 dB after d seconds
        ph = rng.random() * TAU
        g = a
        step0 = TAU * f / RATE
        for i in range(n):
            step = step0 * (glide ** (i / n)) if glide != 1.0 else step0
            ph += step
            out[i] += g * math.sin(ph)
            g *= k
            if g < 1e-5:
                break
    att = max(1, int(attack * RATE))
    for i in range(min(att, n)):
        out[i] *= i / att
    return out


def strike(dur, centre, q, rng, gain=1.0, kind="bp"):
    """the hit: a few ms of noise through a band-pass (a mallet, a fingertip, a knuckle)"""
    n = max(8, int(dur * RATE))
    x = noise(n, rng)
    for i in range(n):
        x[i] *= (1 - i / n) ** 2
    y = biquad(x, kind, centre, q)
    return [v * gain for v in y]


def env_exp(x, tau, attack=0.002):
    n = len(x)
    att = max(1, int(attack * RATE))
    k = math.exp(-1 / (tau * RATE))
    g = 1.0
    for i in range(n):
        x[i] *= (min(1.0, i / att)) * g
        g *= k
    return x


def hann_env(x):
    n = len(x)
    for i in range(n):
        x[i] *= 0.5 - 0.5 * math.cos(TAU * i / max(1, n - 1))
    return x


def sine_glide(f0, f1, dur, harm=None):
    """a sine gliding f0 → f1 (exponential), with extra harmonics [(n, amp)]"""
    n = int(dur * RATE)
    out = [0.0] * n
    ph = 0.0
    for i in range(n):
        f = f0 * (f1 / f0) ** (i / max(1, n))
        ph += TAU * f / RATE
        v = math.sin(ph)
        if harm:
            for h, a in harm:
                if f * h < NYQ * 0.9:
                    v += a * math.sin(ph * h)
        out[i] = v
    return out


class Room:
    """a small Schroeder reverb (4 combs, 2 all-passes) for one channel; `seed` shifts its comb
    lengths a little, so the two channels differ (width)"""

    def __init__(self, size=1.0, damp=0.3, seed=0):
        base = [1116, 1188, 1277, 1356]
        self.combs = [int(c * size * RATE / 44100) + seed * 23 for c in base]
        self.aps = [int(a * RATE / 44100) + seed * 7 for a in (556, 441)]
        self.fb = 0.6 + 0.2 * min(1.0, size)      # (lower: a short room, no metallic ring on clicks)
        self.damp = damp

    def run(self, x):
        n = len(x)
        out = [0.0] * n
        for L in self.combs:
            buf = [0.0] * L
            idx = 0
            filt = 0.0
            for i in range(n):
                y = buf[idx]
                filt = y * (1 - self.damp) + filt * self.damp
                buf[idx] = x[i] + filt * self.fb
                idx = (idx + 1) % L
                out[i] += y * 0.25
        for L in self.aps:
            buf = [0.0] * L
            idx = 0
            for i in range(n):
                b = buf[idx]
                y = -out[i] + b
                buf[idx] = out[i] + b * 0.5
                idx = (idx + 1) % L
                out[i] = y
        return out


# ── the instruments ─────────────────────────────────────────────────────────────────────────────
# each: tap(f, g) a short percussive hit, tone(f, g, long) a pitched note, slide(f0, f1, dur, g) a
# glide, air(up, dur, g) a breath of filtered noise; and a room (reverb mix, size)

class Soft:
    """felt: round tones with a quick second harmonic, soft ticks"""
    wet, size = 0.07, 0.5

    def __init__(self, rng):
        self.rng = rng

    def tap(self, f, g):
        click = strike(0.006, f * 1.4, 1.2, self.rng, 0.9)
        body = env_exp(sine_glide(f * 0.5, f * 0.46, 0.05), 0.012, 0.0008)
        return mix_into(click, body, 0, 0.5)

    def tone(self, f, g, long=False):
        d = 0.55 if long else 0.24
        x = modal(f, [1, 2, 3], [1, 0.22, 0.05], [d, d * 0.35, d * 0.2], d * 1.2, attack=0.004, rng=self.rng)
        return biquad(x, "lp", 6000)

    def slide(self, f0, f1, dur, g):
        return hann_env(sine_glide(f0, f1, dur, [(2, 0.15)]))

    def air(self, up, dur, g):
        x = noise(int(dur * RATE), self.rng)
        x = sweep_filter(x, "bp", 700 if up else 2600, 2600 if up else 700, 1.2)
        return [v * 0.6 for v in hann_env(x)]


class Glass:
    """a wine glass struck: partials 1 : 2.32 : 4.25 : 6.63 ringing on, a bright tink first"""
    wet, size = 0.24, 1.0

    def __init__(self, rng):
        self.rng = rng

    def tap(self, f, g):
        f = min(f * 1.3, 4200)
        x = modal(f, [1, 2.32, 4.25], [1, 0.5, 0.25], [0.12, 0.06, 0.03], 0.18, attack=0.0005, rng=self.rng)
        return mix_into(x, strike(0.003, 7000, 0.8, self.rng, 0.35, "hp"))

    def tone(self, f, g, long=False):
        d = 1.4 if long else 0.7
        x = modal(f, [1, 2.32, 4.25, 6.63], [1, 0.45, 0.22, 0.1], [d, d * 0.55, d * 0.3, d * 0.18], d,
                  attack=0.001, rng=self.rng)
        return mix_into(x, strike(0.003, 6000, 0.9, self.rng, 0.25, "hp"))

    def slide(self, f0, f1, dur, g):
        x = sine_glide(f0, f1, dur, [(2.32, 0.25)])
        return env_exp(x, dur * 0.6, 0.01)

    def air(self, up, dur, g):
        x = noise(int(dur * RATE), self.rng)
        x = sweep_filter(x, "bp", 2500 if up else 7000, 7000 if up else 2500, 2.0)
        return [v * 0.45 for v in hann_env(x)]


class Pop:
    """bubbles: a sine whose pitch rises as the bubble closes, gone in a blink"""
    wet, size = 0.06, 0.4

    def __init__(self, rng):
        self.rng = rng

    def bubble(self, f, dur):
        x = sine_glide(f * 0.75, f * 1.35, dur)
        return env_exp(x, dur * 0.35, 0.001)

    def tap(self, f, g):
        return self.bubble(min(f, 1800), 0.035)

    def tone(self, f, g, long=False):
        return self.bubble(f, 0.16 if long else 0.09)

    def slide(self, f0, f1, dur, g):
        return env_exp(sine_glide(f0, f1 * 1.2, dur), dur * 0.5, 0.002)

    def air(self, up, dur, g):
        # a soft "bloop" of water instead of a breath
        x = noise(int(dur * RATE), self.rng)
        x = sweep_filter(x, "bp", 300 if up else 900, 900 if up else 300, 3.0)
        return [v * 0.5 for v in hann_env(x)]


class Wood:
    """a woodblock knock for taps (partials 1 : 2.57 : 4.2, gone in ~50 ms, a hard mallet click on
    it) and marimba bars for notes (1 : 4 : 10, the lowest ringing longest); hardly any room: wood is dry"""
    wet, size = 0.035, 0.3

    def __init__(self, rng):
        self.rng = rng

    def knock(self, f, length=1.0):
        x = modal(f, [1, 2.57, 4.2], [1, 0.45, 0.2], [0.07 * length, 0.03 * length, 0.015 * length], 0.12 * length,
                  attack=0.0004, rng=self.rng)
        mix_into(x, strike(0.004, f * 1.8, 2.5, self.rng, 0.55))
        return mix_into(x, strike(0.0015, 5000, 0.7, self.rng, 0.2, "hp"))

    def tap(self, f, g):
        # (taps sit where a small block knocks: 900 Hz–1.6 kHz)
        return self.knock(max(800, min(1600, f * 0.7)))

    def tone(self, f, g, long=False):
        f = max(220, min(f * 0.5, 1400))           # (marimba range: an octave down)
        d = 0.5 if long else 0.32
        x = modal(f, [1, 3.98, 9.9], [1, 0.32, 0.1], [d, d * 0.2, d * 0.07], d * 1.1, attack=0.0008, rng=self.rng)
        mix_into(x, strike(0.005, f * 2.5, 1.5, self.rng, 0.35))
        return x

    def slide(self, f0, f1, dur, g):
        # wood can't glide: a quick run of knocks instead (a ratchet), rising or falling
        out = []
        steps = 4
        for k in range(steps):
            f = f0 * (f1 / f0) ** (k / (steps - 1))
            mix_into(out, self.knock(max(500, min(1800, f)), 0.7), k * dur / steps, 0.8)
        return out

    def air(self, up, dur, g):
        # a brush across the grain: dark, short
        x = noise(int(dur * RATE * 0.7), self.rng)
        x = sweep_filter(x, "bp", 400 if up else 1200, 1200 if up else 400, 0.9)
        return [v * 0.35 for v in hann_env(x)]


PACKS = {"soft": Soft, "glass": Glass, "pop": Pop, "wood": Wood}


# ── the score: what each event plays ────────────────────────────────────────────────────────────
# (kind, at s, args…): ("tap", t, f, g) ("tone", t, note, g, long) ("slide", t, f0, f1, dur, g)
# ("air", t, up, dur, g)

SCORE = {
    "click":        [("tap", 0, 2100, 1)],
    "type":         [("tap", 0, 2600, 0.8)],
    "erase":        [("tap", 0, 1500, 0.8)],
    "tick":         [("tap", 0, 1800, 0.9)],
    "toggle-on":    [("tone", 0, "E6", 0.8, False), ("tone", 0.055, "A6", 1, False)],
    "toggle-off":   [("tone", 0, "A6", 0.8, False), ("tone", 0.055, "E6", 1, False)],
    "open":         [("air", 0, True, 0.16, 0.6), ("tone", 0.03, "G5", 0.7, False), ("tone", 0.08, "D6", 0.8, False)],
    "close":        [("air", 0, False, 0.14, 0.6), ("tone", 0.02, "D6", 0.7, False), ("tone", 0.07, "G5", 0.8, False)],
    "drop":         [("tap", 0, 900, 0.8), ("tone", 0.02, "C5", 0.9, False)],
    "workspace":    [("air", 0, True, 0.12, 0.7), ("tone", 0.04, "A5", 0.6, False)],
    "shutter":      [("tap", 0, 2400, 1), ("tap", 0.07, 1500, 0.9)],
    "notify":       [("tone", 0, "C6", 0.9, True), ("tone", 0.11, "G6", 0.8, True)],
    "lock":         [("tone", 0, "G5", 0.9, False), ("tone", 0.1, "C5", 1, True)],
    "unlock":       [("tone", 0, "C5", 0.8, False), ("tone", 0.08, "E5", 0.8, False), ("tone", 0.16, "G5", 0.9, True)],
    "error":        [("tone", 0, "E4", 1, False), ("tone", 0.12, "Eb4", 1, True)],
    "wallpaper":    [("tone", 0, "C5", 0.7, False), ("tone", 0.06, "E5", 0.7, False), ("tone", 0.12, "G5", 0.7, False),
                     ("tone", 0.18, "C6", 0.8, True)],
    "window-open":  [("slide", 0, 420, 840, 0.11, 0.7), ("tone", 0.07, "E6", 0.5, False)],
    "window-close": [("slide", 0, 840, 420, 0.11, 0.7), ("tone", 0.07, "A5", 0.5, False)],
    "launch":       [("air", 0, True, 0.2, 0.5), ("tone", 0.02, "G5", 0.7, False), ("tone", 0.07, "C6", 0.7, False),
                     ("tone", 0.12, "E6", 0.8, True)],
    "dismiss":      [("air", 0, False, 0.12, 0.7), ("tap", 0.05, 1300, 0.6)],
    "plug":         [("tone", 0, "C5", 0.9, False), ("tone", 0.08, "G5", 1, False)],
    "unplug":       [("tone", 0, "G5", 0.9, False), ("tone", 0.08, "C5", 1, False)],
}

# notification tones (sounds/notify): (instrument, score); "alert" for urgent ones
TONES = {
    "chime":   ("soft", [("tone", 0, "E6", 0.9, True), ("tone", 0.12, "B6", 0.8, True)]),
    "glass":   ("glass", [("tone", 0, "D6", 0.9, True), ("tone", 0.09, "G6", 0.8, True), ("tone", 0.18, "D7", 0.6, True)]),
    "bubble":  ("pop", [("tone", 0, "G5", 1, False), ("tone", 0.09, "D6", 1, False), ("tone", 0.16, "G6", 0.9, True)]),
    "marimba": ("wood", [("tone", 0, "C6", 0.9, False), ("tone", 0.08, "E6", 0.9, False), ("tone", 0.16, "G6", 1, True)]),
    "soft":    ("soft", [("tone", 0, "C5", 1, True), ("tone", 0.16, "G5", 0.8, True)]),
    "alert":   ("soft", [("tone", 0, "A5", 1, False), ("tone", 0.12, "A5", 1, False), ("tone", 0.24, "E6", 1, True)]),
}


def perform(inst, score):
    mono = []
    for ev in score:
        kind, at = ev[0], ev[1]
        if kind == "tap":
            src, g = inst.tap(ev[2], ev[3]), ev[3]
        elif kind == "tone":
            src, g = inst.tone(note(ev[2]), ev[3], ev[4]), ev[3]
        elif kind == "slide":
            src, g = inst.slide(ev[2], ev[3], ev[4], ev[5]), ev[5]
        else:
            src, g = inst.air(ev[2], ev[3], ev[4]), ev[4]
        mix_into(mono, src, at, g)
    return mono


def stereo(inst, mono, rng, short=False):
    """the room (two slightly different ones: width), a hair of delay between the ears, an echo for
    the packs that have one (ping-pong for cyber), then trimmed to where it falls silent. Sounds
    that are only taps get half the room: a click shouldn't hang in the air"""
    tail = 0.25 + inst.size * 0.35 + (getattr(inst, "echo", 0) * 3)
    mono = mono + [0.0] * int(tail * RATE)
    left = Room(inst.size, 0.45, 0).run(mono)
    right = Room(inst.size, 0.45, 1).run(mono)
    d = 18                                                        # 0.4 ms: a little width
    wet = inst.wet * (0.5 if short else 1.0)
    L = [m + wet * l for m, l in zip(mono, left)]
    R = [(mono[i - d] if i >= d else 0.0) + wet * r for i, r in enumerate(right)]
    echo = getattr(inst, "echo", 0)
    if echo:
        e = int(echo * RATE)
        for i in range(e, len(L)):
            L[i] += 0.28 * L[i - e]
            R[i] += 0.28 * R[i - e]
    # trim the silent end, fade the last 8 ms, peak at -1.5 dBFS
    peak = max(1e-9, max(max(abs(v) for v in L), max(abs(v) for v in R)))
    end = len(L)
    while end > RATE // 50 and abs(L[end - 1]) < peak * 0.002 and abs(R[end - 1]) < peak * 0.002:
        end -= 1
    L, R = L[:end], R[:end]
    f = min(len(L), int(0.008 * RATE))
    for i in range(f):
        k = i / f
        L[-1 - i] *= k
        R[-1 - i] *= k
    s = 0.84 / peak
    return [v * s for v in L], [v * s for v in R]


def write(path, L, R):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        clip = lambda v: max(-32767, min(32767, int(v * 32767)))
        w.writeframes(b"".join(struct.pack("<hh", clip(a), clip(b)) for a, b in zip(L, R)))


if __name__ == "__main__":
    for pack, cls in PACKS.items():
        for name, score in SCORE.items():
            rng = random.Random(f"{pack}/{name}")
            inst = cls(rng)
            short = all(ev[0] == "tap" for ev in score)
            L, R = stereo(inst, perform(inst, score), rng, short)
            write(os.path.join(OUT, pack, name + ".wav"), L, R)
        print("wrote", pack, flush=True)
    for name, (pack, score) in TONES.items():
        rng = random.Random(f"notify/{name}")
        inst = PACKS[pack](rng)
        L, R = stereo(inst, perform(inst, score), rng)
        write(os.path.join(OUT, "notify", name + ".wav"), L, R)
    print("wrote", len(TONES), "notification tones to", os.path.normpath(os.path.join(OUT, "notify")))
