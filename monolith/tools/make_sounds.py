#!/usr/bin/env python3
"""Monolith's interface sounds, synthesised (no recordings): short 16-bit mono WAVs written
into shell/sounds/<pack>/. Each pack plays the same events with its own voice:

  soft   rounded sine blips (the original set)
  glass  bell-like, with inharmonic overtones and a longer ring
  pop    quick bubbly drops in pitch
  retro  square waves, 8-bit arpeggios
  wood   short knocks: a damped low tone with a little noise on the hit
  cyber  the Cyberpunk style's: bit-crushed FM chirps that stutter like a bad signal, a burst of
         digital noise on the hit and a short echo

Run again after changing a recipe."""
import math, os, random, struct, wave

RATE = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "sounds")
random.seed(7)

# events: a list of notes (start s, freq from, freq to, dur s, gain) and the clip's length.
# Every pack plays these notes; the pack decides how a note sounds.
EVENTS = {
    "click":      ([(0, 1900, 1500, 0.035, 1)], 0.06),
    "toggle-on":  ([(0, 880, 990, 0.06, 1), (0.045, 1320, 1480, 0.08, 0.8)], 0.16),
    "toggle-off": ([(0, 1320, 1180, 0.06, 0.8), (0.045, 880, 780, 0.08, 1)], 0.16),
    "open":       ([(0, 520, 780, 0.12, 1), (0.03, 1040, 1300, 0.1, 0.35)], 0.18),
    "close":      ([(0, 780, 520, 0.1, 1), (0.02, 1300, 1040, 0.08, 0.3)], 0.15),
    "drop":       ([(0, 660, 440, 0.09, 1)], 0.12),
    # new ones
    "tick":       ([(0, 1400, 1400, 0.025, 1)], 0.04),                       # volume / brightness steps
    "workspace":  ([(0, 600, 900, 0.07, 0.8)], 0.1),
    "shutter":    ([(0, 2400, 1200, 0.03, 1), (0.05, 1800, 900, 0.04, 0.9)], 0.12),
    "notify":     ([(0, 988, 988, 0.12, 1), (0.1, 1319, 1319, 0.2, 0.9)], 0.36),
    "lock":       ([(0, 660, 660, 0.08, 1), (0.08, 440, 440, 0.14, 1)], 0.26),
    "unlock":     ([(0, 440, 440, 0.08, 1), (0.08, 660, 660, 0.08, 0.8), (0.16, 880, 880, 0.14, 0.8)], 0.34),
    "error":      ([(0, 330, 300, 0.12, 1), (0.13, 300, 260, 0.16, 1)], 0.32),
    "wallpaper":  ([(0, 523, 523, 0.1, 0.7), (0.06, 659, 659, 0.1, 0.7), (0.12, 784, 784, 0.18, 0.8)], 0.34),
    # windows, apps, typing, notifications going, the charger (Settings -> Sound -> Sound effects)
    "window-open":  ([(0, 500, 700, 0.06, 0.9), (0.04, 750, 1000, 0.09, 0.7)], 0.16),
    "window-close": ([(0, 900, 650, 0.06, 0.8), (0.04, 600, 420, 0.09, 0.9)], 0.16),
    "launch":       ([(0, 660, 660, 0.05, 0.8), (0.045, 880, 880, 0.05, 0.8), (0.09, 1320, 1400, 0.1, 0.9)], 0.22),
    "type":         ([(0, 2600, 2200, 0.012, 1)], 0.025),
    "erase":        ([(0, 1500, 1150, 0.016, 1)], 0.032),
    "dismiss":      ([(0, 1100, 700, 0.07, 0.9)], 0.1),
    "plug":         ([(0, 440, 440, 0.06, 0.9), (0.06, 880, 880, 0.1, 0.9)], 0.2),
    "unplug":       ([(0, 880, 880, 0.06, 0.9), (0.06, 440, 440, 0.1, 0.9)], 0.2),
}

def env(i, m, attack, power):
    t = i / m
    return min(1.0, i / max(1, attack * RATE)) * (1 - t) ** power

def soft(phase, f, i, m):
    return env(i, m, 0.004, 2.2) * (math.sin(phase) + 0.18 * math.sin(2 * phase))

def glass(phase, f, i, m):
    # bell partials ring on past the note's own length (the clip is stretched below)
    e = env(i, m, 0.002, 1.4)
    return e * (math.sin(phase) + 0.35 * math.sin(2.76 * phase) * (1 - i / m) + 0.15 * math.sin(5.4 * phase) * (1 - i / m) ** 2)

def pop(phase, f, i, m):
    return env(i, m, 0.001, 3.5) * math.sin(phase)

def retro(phase, f, i, m):
    sq = 1.0 if math.sin(phase) >= 0 else -1.0
    return 0.45 * sq * (1 if i < m * 0.85 else (m - i) / (m * 0.15))

def wood(phase, f, i, m):
    e = env(i, m, 0.0005, 6)
    noise = (random.random() * 2 - 1) * max(0, 1 - i / (0.006 * RATE))
    return e * (math.sin(phase * 0.5) + 0.4 * math.sin(phase * 1.5)) + 0.5 * noise

def cyber(phase, f, i, m):
    # FM: the modulator dies away faster than the note, so it starts as a buzz and ends as a tone,
    # with a slightly detuned saw underneath
    t = i / m
    mod = math.sin(phase * 2.0) * 2.6 * (1 - t) ** 2
    saw = ((phase * 1.006 / (2 * math.pi)) % 1.0) * 2 - 1
    return env(i, m, 0.001, 2.0) * (math.sin(phase + mod) + 0.25 * saw)

def cyber_post(buf, name):
    rnd = random.Random(sum(map(ord, name)))
    n = len(buf)
    # a burst of digital noise on the hit, held in 4-sample steps
    held = 0.0
    for i in range(min(n, int(0.007 * RATE))):
        if i % 4 == 0:
            held = rnd.random() * 2 - 1
        buf[i] += 0.5 * held * (1 - i / (0.007 * RATE))
    # the bad signal: in 9 ms slices, now and then a slice drops out or repeats the one before
    sl = int(0.009 * RATE)
    out = buf[:]
    for k in range(1, n // sl):
        r = rnd.random()
        a, b = k * sl, min(n, (k + 1) * sl)
        if r < 0.12:
            for i in range(a, b): out[i] = 0.0
        elif r < 0.3:
            for i in range(a, b): out[i] = buf[i - sl]
    # sample-and-hold to 12 kHz and 6 bits: the crunch
    held = 0.0
    for i in range(n):
        if i % 4 == 0:
            held = round(out[i] * 32) / 32
        out[i] = held
    # a short digital echo
    d = int(0.038 * RATE)
    for i in range(d, n):
        out[i] += 0.3 * out[i - d]
    return out

PACKS = {
    # name: (voice, how much longer notes ring, pitch factor, pitch glide on every note)
    "soft":  (soft, 1.0, 1.0, 1.0),
    "glass": (glass, 2.2, 1.25, 1.0),
    "pop":   (pop, 1.0, 0.8, 0.55),
    "retro": (retro, 1.0, 0.75, 1.0),
    "wood":  (wood, 1.3, 0.5, 0.9),
    "cyber": (cyber, 1.35, 0.9, 1.0),
}
POST = {"cyber": cyber_post}

def render(parts, length, voice, ring, pitch, glide, post=None, name=""):
    n = int(RATE * length * ring)
    buf = [0.0] * n
    for start, f0, f1, dur, gain in parts:
        f0, f1 = f0 * pitch, f1 * pitch * glide
        s0, m = int(start * RATE), int(dur * ring * RATE)
        phase = 0.0
        for i in range(m):
            if s0 + i >= n:
                break
            f = f0 + (f1 - f0) * (i / m)
            phase += 2 * math.pi * f / RATE
            buf[s0 + i] += gain * voice(phase, f, i, m)
    if post:
        buf = post(buf, name)
    peak = max(1e-9, max(abs(x) for x in buf))
    return [x / peak * 0.8 for x in buf]

for pack, (voice, ring, pitch, glide) in PACKS.items():
    d = os.path.join(OUT, pack)
    os.makedirs(d, exist_ok=True)
    for name, (parts, length) in EVENTS.items():
        with wave.open(os.path.join(d, name + ".wav"), "wb") as w:
            w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
            w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in render(parts, length, voice, ring, pitch, glide, POST.get(pack), name)))
print("wrote", len(EVENTS), "sounds for", ", ".join(PACKS), "to", os.path.normpath(OUT))

# notification tones (Settings -> Sound -> Sound effects -> Notifications): sounds/notify/<tone>.wav,
# each in a voice above; "alert" is the one for urgent notifications
TONES = {
    # tone: (voice, ring, notes, length)
    "chime":   (soft, 1.0, [(0, 988, 988, 0.12, 1), (0.1, 1319, 1319, 0.22, 0.9)], 0.38),
    "glass":   (glass, 2.0, [(0, 1175, 1175, 0.1, 0.9), (0.08, 1568, 1568, 0.12, 0.8), (0.16, 2349, 2349, 0.16, 0.6)], 0.42),
    "bubble":  (pop, 1.0, [(0, 900, 500, 0.06, 1), (0.08, 1200, 650, 0.07, 0.9)], 0.2),
    "marimba": (wood, 1.4, [(0, 1046, 1046, 0.08, 0.9), (0.07, 1318, 1318, 0.08, 0.9), (0.14, 1568, 1568, 0.14, 1)], 0.36),
    "soft":    (soft, 1.5, [(0, 523, 523, 0.18, 1), (0.14, 784, 784, 0.26, 0.8)], 0.5),
    "digital": (cyber, 1.2, [(0, 1320, 1320, 0.05, 1), (0.07, 1760, 1760, 0.05, 1), (0.14, 2640, 2600, 0.12, 0.9)], 0.34),
    "alert":   (retro, 1.0, [(0, 1046, 1046, 0.07, 1), (0.11, 1046, 1046, 0.07, 1), (0.22, 1046, 1046, 0.12, 1)], 0.4),
}
d = os.path.join(OUT, "notify")
os.makedirs(d, exist_ok=True)
for name, (voice, ring, parts, length) in TONES.items():
    with wave.open(os.path.join(d, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in render(parts, length, voice, ring, 1.0, 1.0, cyber_post if voice is cyber else None, name)))
print("wrote", len(TONES), "notification tones to", os.path.normpath(d))
