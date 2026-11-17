#!/usr/bin/env python3
"""Monolith's sound packs from real recordings: Kenney's Interface Sounds and UI Audio (CC0, public
domain: https://kenney.nl). The synthesised packs (tools/make_sounds.py) sounded generated: pure
tones and perfect envelopes. These are recordings of real things (switches, clicks, glass, drops),
picked per pack by character and levelled so a pack sounds even.

    make_sounds_recorded.py KENNEY_DIR

KENNEY_DIR holds the two packs (any layout: the files are found by name), e.g. clones of
github.com/Calinou/kenney-interface-sounds and github.com/Calinou/kenney-ui-audio. Writes
shell/sounds/<pack>/<event>.wav (and shell/sounds/notify/<tone>.wav): 48 kHz 16-bit stereo, the
leading silence cut, a short fade at the end, each pack at its own loudness. Needs ffmpeg.
"""
import math
import os
import shutil
import struct
import subprocess
import sys
import tempfile
import wave

OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "shell", "sounds")

# every event the shell plays (core/Sounds.qml), per pack: the recording it uses
PACKS = {
    # dark and knocky: dull switches, thumps, low knocks
    "wood": {
        "click": "switch_006", "tick": "click_005", "toggle-on": "switch_005", "toggle-off": "switch_007",
        "type": "select_007", "erase": "back_002", "open": "switch_003", "close": "switch_004",
        "window-open": "drop_003", "window-close": "drop_002", "launch": "bong_001", "dismiss": "back_004",
        "drop": "drop_004", "error": "error_006", "lock": "switch_002", "unlock": "select_006",
        "plug": "select_005", "unplug": "back_001", "shutter": "click_002", "notify": "bong_001",
        "wallpaper": "select_004", "workspace": "select_004",
    },
    # bright and ringing: glass taps, ticks, plucks
    "glass": {
        "click": "glass_006", "tick": "tick_001", "toggle-on": "glass_002", "toggle-off": "glass_005",
        "type": "tick_002", "erase": "glass_003", "open": "glass_001", "close": "glass_003",
        "window-open": "glass_004", "window-close": "pluck_002", "launch": "glass_004", "dismiss": "tick_004",
        "drop": "pluck_001", "error": "error_002", "lock": "toggle_003", "unlock": "toggle_002",
        "plug": "glass_001", "unplug": "glass_005", "shutter": "click_004", "notify": "glass_004",
        "wallpaper": "glass_001", "workspace": "tick_004",
    },
    # drops and plucks
    "pop": {
        "click": "drop_001", "tick": "select_001", "toggle-on": "select_003", "toggle-off": "select_004",
        "type": "select_002", "erase": "back_003", "open": "drop_004", "close": "drop_002",
        "window-open": "pluck_001", "window-close": "drop_003", "launch": "pluck_002", "dismiss": "scratch_001",
        "drop": "drop_004", "error": "error_004", "lock": "toggle_001", "unlock": "toggle_004",
        "plug": "select_003", "unplug": "back_001", "shutter": "click_003", "notify": "drop_002",
        "wallpaper": "drop_001", "workspace": "select_005",
    },
    # quiet real switches and mouse clicks
    "soft": {
        "click": "click1", "tick": "rollover2", "toggle-on": "switch23", "toggle-off": "switch22",
        "type": "click3", "erase": "switch24", "open": "switch25", "close": "switch21",
        "window-open": "click2", "window-close": "switch20", "launch": "switch16", "dismiss": "rollover5",
        "drop": "switch27", "error": "error_008", "lock": "switch30", "unlock": "switch32",
        "plug": "switch18", "unplug": "switch15", "shutter": "mouseclick1", "notify": "rollover1",
        "wallpaper": "rollover3", "workspace": "switch10",
    },
}
# the notification tones (Settings -> Sound -> Notification sound)
NOTIFY = {"chime": "glass_004", "glass": "glass_001", "bubble": "drop_002", "marimba": "bong_001",
          "soft": "rollover1", "alert": "error_003"}
# how loud each pack is (RMS of the sound, dBFS)
LEVEL = {"wood": -17.0, "glass": -19.0, "pop": -18.0, "soft": -23.0, "notify": -17.0}


def find_all(root):
    out = {}
    for d, _dirs, files in os.walk(root):
        for f in files:
            if f.lower().endswith((".wav", ".ogg")):
                out.setdefault(os.path.splitext(f)[0], os.path.join(d, f))
    return out


def load(path, tmp):
    """the file as 48 kHz stereo 16-bit samples (ffmpeg does the conversion)"""
    dst = os.path.join(tmp, "x.wav")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", path, "-ar", "48000", "-ac", "2", "-sample_fmt", "s16", dst], check=True)
    with wave.open(dst) as w:
        raw = w.readframes(w.getnframes())
    return list(struct.unpack("<%dh" % (len(raw) // 2), raw))


def shape(s, level):
    """leading silence cut, levelled to `level` dBFS RMS (peak under -1 dBFS), a fade at the end"""
    frames = len(s) // 2
    mono = [max(abs(s[2 * i]), abs(s[2 * i + 1])) for i in range(frames)]
    peak = max(1, max(mono))
    start = next((i for i, v in enumerate(mono) if v > peak * 0.02), 0)
    start = max(0, start - 48)                       # (a millisecond before the sound starts)
    # and the silence after it (what's left of its tail under -50 dB): 40 ms past that
    end = frames - next((i for i, v in enumerate(reversed(mono)) if v > peak * 0.003), 0)
    end = min(frames, end + int(0.04 * 48000))
    s = s[2 * start:2 * end]
    frames = len(s) // 2
    rms = math.sqrt(sum(x * x for x in s) / max(1, len(s))) or 1
    gain = 10 ** (level / 20) * 32767 / rms
    gain = min(gain, 32767 * 10 ** (-1 / 20) / max(1, max(abs(x) for x in s)))
    fade = min(frames, int(0.006 * 48000))          # 6 ms
    out = []
    for i in range(frames):
        g = gain * (1 if i < frames - fade else (frames - i) / fade)
        out.append(int(max(-32768, min(32767, s[2 * i] * g))))
        out.append(int(max(-32768, min(32767, s[2 * i + 1] * g))))
    return out


def save(path, s):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(48000)
        w.writeframes(struct.pack("<%dh" % len(s), *s))


def main():
    if len(sys.argv) != 2 or not shutil.which("ffmpeg"):
        sys.exit(__doc__)
    files = find_all(sys.argv[1])
    missing = sorted({n for p in PACKS.values() for n in p.values()} | set(NOTIFY.values()) - set(files))
    missing = [m for m in missing if m not in files]
    if missing:
        sys.exit("not found in %s: %s" % (sys.argv[1], ", ".join(missing)))
    with tempfile.TemporaryDirectory() as tmp:
        for pack, events in PACKS.items():
            for event, name in events.items():
                save(os.path.join(OUT, pack, event + ".wav"), shape(load(files[name], tmp), LEVEL[pack]))
            print(pack, len(events), "sounds")
        for tone, name in NOTIFY.items():
            save(os.path.join(OUT, "notify", tone + ".wav"), shape(load(files[name], tmp), LEVEL["notify"]))
        print("notify", len(NOTIFY), "tones")
    with open(os.path.join(OUT, "CREDITS.txt"), "w") as f:
        f.write("Monolith's sound packs (glass, pop, soft, wood) and notification tones are recordings from\n"
                "Kenney's \"Interface Sounds\" and \"UI Audio\" packs (https://kenney.nl), released under\n"
                "Creative Commons Zero (CC0, public domain). Picked, trimmed and levelled by\n"
                "tools/make_sounds_recorded.py. Thank you, Kenney.\n")


if __name__ == "__main__":
    main()
