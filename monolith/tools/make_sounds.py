#!/usr/bin/env python3
"""Monolith's interface sounds, synthesised (no recordings): short soft blips written as
16-bit mono WAVs into shell/sounds/. Run again after changing a recipe."""
import math, os, struct, wave

RATE = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "sounds")

def tone(parts, length):
    """parts: [(start s, freq from, freq to, dur s, gain)] mixed; a soft attack and decay each."""
    n = int(RATE * length)
    buf = [0.0] * n
    for start, f0, f1, dur, gain in parts:
        s0, m = int(start * RATE), int(dur * RATE)
        phase = 0.0
        for i in range(m):
            if s0 + i >= n:
                break
            t = i / m
            f = f0 + (f1 - f0) * t
            phase += 2 * math.pi * f / RATE
            env = min(1.0, i / (0.004 * RATE)) * (1 - t) ** 2.2
            # a touch of the octave for a rounder, glassier blip
            buf[s0 + i] += gain * env * (math.sin(phase) + 0.18 * math.sin(2 * phase))
    peak = max(1e-9, max(abs(x) for x in buf))
    return [x / peak * 0.8 for x in buf]

SOUNDS = {
    "click":      ([(0, 1900, 1500, 0.035, 1)], 0.05),
    "toggle-on":  ([(0, 880, 990, 0.06, 1), (0.045, 1320, 1480, 0.08, 0.8)], 0.14),
    "toggle-off": ([(0, 1320, 1180, 0.06, 0.8), (0.045, 880, 780, 0.08, 1)], 0.14),
    "open":       ([(0, 520, 780, 0.12, 1), (0.03, 1040, 1300, 0.1, 0.35)], 0.16),
    "close":      ([(0, 780, 520, 0.1, 1), (0.02, 1300, 1040, 0.08, 0.3)], 0.13),
    "drop":       ([(0, 660, 440, 0.09, 1)], 0.11),
}

os.makedirs(OUT, exist_ok=True)
for name, (parts, length) in SOUNDS.items():
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(RATE)
        w.writeframes(b"".join(struct.pack("<h", int(x * 32767)) for x in tone(parts, length)))
print("wrote", ", ".join(SOUNDS), "to", os.path.normpath(OUT))
