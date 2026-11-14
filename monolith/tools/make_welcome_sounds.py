#!/usr/bin/env python3
"""The welcome tour's sounds, synthesised (no recordings): 16-bit stereo WAVs written into
shell/sounds/welcome/. They keep time with the intro's animation in apps/Welcome.qml, which
runs on the same clock (the times below are its milliseconds / 1000):

  intro  0.0-1.25 a warm swell and a soft breath of air (the line of light, the slab rising)
         1.25     a quiet bell chord (the slab settles, the card unfolds)
         2.1-2.7  a rising arpeggio (the title, letter by letter)
         2.9      a glint (the shine across the title)
  step   a page turning: a short airy whoosh and two soft notes
  done   all set: a quick arpeggio as the check spins in, a ringing chord as it zooms

Run again after changing a recipe."""
import math, os, random, struct, wave

RATE = 48000
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "sounds", "welcome")
TAU = 2 * math.pi


class Mix:
    def __init__(self, seconds):
        self.n = int(seconds * RATE)
        self.l = [0.0] * self.n
        self.r = [0.0] * self.n

    def add(self, start, dur, fn, gain=1.0, pan=0.0):
        """fn(t, i) -> sample for t seconds into the note; pan -1 left … 1 right (equal power)"""
        a = (pan + 1) * math.pi / 4
        gl, gr = math.cos(a) * gain, math.sin(a) * gain
        s0 = int(start * RATE)
        for i in range(int(dur * RATE)):
            k = s0 + i
            if k >= self.n:
                break
            v = fn(i / RATE, i)
            self.l[k] += v * gl
            self.r[k] += v * gr


def bell(freq, decay):
    # glass-like: a sine with inharmonic partials that die away sooner
    def fn(t, i):
        att = min(1.0, t / 0.003)
        p = TAU * freq * t
        return att * (math.exp(-t / decay) * math.sin(p)
                      + 0.32 * math.exp(-t / (decay * 0.45)) * math.sin(2.76 * p)
                      + 0.12 * math.exp(-t / (decay * 0.22)) * math.sin(5.4 * p))
    return fn


def pluck(freq, decay):
    def fn(t, i):
        att = min(1.0, t / 0.004)
        p = TAU * freq * t
        return att * math.exp(-t / decay) * (math.sin(p) + 0.25 * math.sin(2 * p) * math.exp(-t / (decay * 0.3)))
    return fn


def sweep(f0, f1, dur, env):
    # a sine gliding exponentially from f0 to f1 (phase kept continuous)
    state = {"ph": 0.0}
    def fn(t, i):
        f = f0 * (f1 / f0) ** min(1.0, t / dur)
        state["ph"] += TAU * f / RATE
        return env(t) * math.sin(state["ph"])
    return fn


def noise(seed, cut0, cut1, dur, env):
    # white noise through a one-pole low-pass whose cutoff glides cut0 → cut1
    rnd = random.Random(seed)
    state = {"y": 0.0}
    def fn(t, i):
        c = cut0 * (cut1 / cut0) ** min(1.0, t / dur)
        a = 1 - math.exp(-TAU * c / RATE)
        state["y"] += a * ((rnd.random() * 2 - 1) - state["y"])
        return env(t) * state["y"]
    return fn


def reverb(mix, wet=0.3, size=1.0):
    """Schroeder reverb: four damped combs into two all-passes, a little different per side"""
    def run(x, spread):
        k = RATE / 44100 * size
        combs = [int((d + spread) * k) for d in (1557, 1617, 1491, 1422)]
        out = [0.0] * len(x)
        for d in combs:
            buf = [0.0] * d
            idx, low = 0, 0.0
            for i, v in enumerate(x):
                y = buf[idx]
                low = y * 0.7 + low * 0.3
                buf[idx] = v + low * 0.83
                idx = (idx + 1) % d
                out[i] += y * 0.25
        for d in (int(225 * k), int(556 * k)):
            buf = [0.0] * d
            idx = 0
            for i, v in enumerate(out):
                b = buf[idx]
                y = -v + b
                buf[idx] = v + b * 0.5
                idx = (idx + 1) % d
                out[i] = y
        return out
    wl, wr = run(mix.l, 0), run(mix.r, 23)
    mix.l = [d + w * wet for d, w in zip(mix.l, wl)]
    mix.r = [d + w * wet for d, w in zip(mix.r, wr)]


def write(mix, name, fade=0.3):
    peak = max(1e-9, max(max(abs(v) for v in mix.l), max(abs(v) for v in mix.r)))
    g = 0.89 / peak
    nf = int(fade * RATE)
    os.makedirs(OUT, exist_ok=True)
    frames = bytearray()
    for i in range(mix.n):
        f = 1.0 if i < mix.n - nf else (mix.n - i) / nf
        for v in (mix.l[i], mix.r[i]):
            frames += struct.pack("<h", int(max(-1.0, min(1.0, v * g * f)) * 32767))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(frames))


A2, E3, A3, CS4 = 110.0, 164.81, 220.0, 277.18
HIT = 1.25


def intro():
    m = Mix(4.8)
    # the swell: a soft A-major pad (detuned pairs, so it breathes), rising to the hit, then a bed
    for f, g in ((A2, 1.0), (E3, 0.8), (A3, 0.7), (CS4, 0.45)):
        for det, pan in ((-0.7, -0.5), (0.7, 0.5)):
            def env(t):
                if t < HIT:
                    return (t / HIT) ** 2.2
                return 0.35 + 0.65 * math.exp(-(t - HIT) / 0.35)
            ff = f + det
            m.add(0, 4.8, lambda t, i, ff=ff, env=env: env(t) * math.exp(-max(0, t - 2.6) / 0.9) * math.sin(TAU * ff * t), 0.05 * g, pan)
    # a soft breath of air as the slab rises, easing away (no hit)
    for seed, pan in ((1, -0.4), (2, 0.4)):
        m.add(0.25, 1.4, noise(seed, 200, 1800, 1.0,
              lambda t: math.sin(math.pi * min(1, t / 1.4)) ** 2), 0.09, pan)
    # the chord as it settles: bells with a slow, soft attack, strummed gently
    for k, (f, pan) in enumerate(((440.0, -0.35), (554.37, 0.3), (659.25, -0.15), (880.0, 0.4))):
        bf = bell(f, 1.4)
        m.add(HIT - 0.05 + k * 0.05, 3.0, lambda t, i, bf=bf: min(1, t / 0.06) * bf(t, i), 0.09, pan)
    # the title: a rising arpeggio, left to right like the letters
    for k, f in enumerate((659.25, 880.0, 1108.73, 1318.51, 1760.0)):
        m.add(2.1 + k * 0.13, 0.9, pluck(f, 0.32), 0.07, -0.6 + k * 0.3)
    # the glint across the title
    m.add(2.9, 0.7, sweep(2600, 5200, 0.6, lambda t: math.sin(math.pi * min(1, t / 0.6)) ** 2), 0.025, 0.2)
    m.add(2.9, 0.7, noise(4, 4000, 9000, 0.6, lambda t: math.sin(math.pi * min(1, t / 0.6)) ** 2), 0.05, -0.2)
    reverb(m, 0.32, 1.15)
    write(m, "intro", 0.6)


def step():
    m = Mix(0.7)
    m.add(0, 0.26, noise(5, 700, 4200, 0.2, lambda t: math.sin(math.pi * min(1, t / 0.24)) ** 2), 0.16, -0.2)
    m.add(0.05, 0.4, pluck(880.0, 0.12), 0.11, 0.1)
    m.add(0.12, 0.45, pluck(1318.51, 0.14), 0.08, 0.3)
    reverb(m, 0.28)
    write(m, "step", 0.15)


def done():
    # the check spinning in: a quick rising arpeggio; the zoom: a ringing chord
    m = Mix(3.0)
    for k, f in enumerate((440.0, 554.37, 659.25, 880.0, 1108.73)):
        m.add(0.02 + k * 0.11, 0.7, pluck(f, 0.22), 0.09, -0.5 + k * 0.25)
    t = 0.78
    for k, (f, pan) in enumerate(((880.0, -0.3), (1108.73, 0.3), (1318.51, 0), (1760.0, 0.45))):
        m.add(t + k * 0.012, 2.2, bell(f, 1.0), 0.1, pan)
    reverb(m, 0.3, 1.1)
    write(m, "done", 0.5)


if __name__ == "__main__":
    intro()
    step()
    done()
    print("wrote", OUT)
