pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Audio bars for the visualiser widgets, from cava's raw output. cava only runs while something
// shows it: a widget calls hold() when it appears and release() when it goes.
// cava's own settings (Store "cava.*", set from a visualiser's settings in the widget editor) are
// shared by every visualiser: a change rewrites the config and restarts cava.
Singleton {
    id: cv
    property int users: 0
    property var bars: []          // 0..1 each, low to high frequencies
    readonly property bool available: true
    function hold() { users++; }
    function release() { users = Math.max(0, users - 1); if (users === 0) bars = []; }

    // every setting with its default; the widget editor lists them (WidgetLayout.cavaOptions)
    readonly property var defaults: ({
        bars: 36, framerate: 60, autosens: true, overshoot: 20, sensitivity: 100,
        lowerCutoff: 50, higherCutoff: 10000, sleepTimer: 0,
        method: "pipewire", source: "auto", sampleRate: 44100, sampleBits: 16, inputChannels: 2, autoconnect: 2, remix: true,
        channels: "stereo", monoOption: "average", reverse: false,
        monstercat: 0, waves: false, noiseReduction: 77,
        eq1: 1, eq2: 1, eq3: 1, eq4: 1, eq5: 1
    })
    function get(k) { const v = Store.get("cava." + k, undefined); return v === undefined || v === null || v === "" ? defaults[k] : v; }
    function n(k, lo, hi) { const v = Number(get(k)); return isNaN(v) ? defaults[k] : Math.max(lo, Math.min(hi, v)); }
    function b(k) { return get(k) === true || get(k) === "true" || get(k) === 1 ? 1 : 0; }
    readonly property int count: n("bars", 4, 256)

    // the config, as lines (rebuilt whenever a setting changes)
    readonly property var lines: {
        const _ = Store.revision;
        const method = ["pipewire", "pulse", "alsa", "jack", "sndio", "oss", "portaudio"].indexOf(String(get("method"))) !== -1 ? String(get("method")) : "pipewire";
        const src = String(get("source") || "auto").replace(/[\r\n]/g, "");
        const lo = n("lowerCutoff", 10, 2000), hi = Math.max(lo + 100, n("higherCutoff", 1000, 22000));
        const out = ["[general]", "bars = " + count, "framerate = " + n("framerate", 1, 360),
            "autosens = " + b("autosens"), "overshoot = " + n("overshoot", 0, 100), "sensitivity = " + n("sensitivity", 1, 1000),
            "lower_cutoff_freq = " + lo, "higher_cutoff_freq = " + hi, "sleep_timer = " + n("sleepTimer", 0, 3600),
            "[input]", "method = " + method, "source = " + src,
            "sample_rate = " + n("sampleRate", 8000, 192000), "sample_bits = " + n("sampleBits", 8, 32),
            "channels = " + n("inputChannels", 1, 2), "autoconnect = " + n("autoconnect", 0, 2), "remix = " + b("remix"),
            "[output]", "method = raw", "raw_target = /dev/stdout", "data_format = ascii", "ascii_max_range = 1000",
            "bar_delimiter = 59", "frame_delimiter = 10",
            "channels = " + (get("channels") === "mono" ? "mono" : "stereo"),
            "mono_option = " + (["average", "left", "right"].indexOf(String(get("monoOption"))) !== -1 ? get("monoOption") : "average"),
            "reverse = " + b("reverse"),
            "[smoothing]", "monstercat = " + n("monstercat", 0, 10), "waves = " + b("waves"), "noise_reduction = " + n("noiseReduction", 0, 100),
            "[eq]"];
        for (let i = 1; i <= 5; i++) out.push(i + " = " + n("eq" + i, 0, 4));
        return out;
    }
    onLinesChanged: if (users > 0) restart()
    function restart() { run.running = false; write.running = false; write.running = true; }

    readonly property string conf: (Quickshell.env("XDG_RUNTIME_DIR") || "/tmp") + "/monolith-cava.conf"
    Process {
        id: write
        command: ["sh", "-c", "f=\"$1\"; shift; printf '%s\\n' \"$@\" > \"$f\"", "sh", cv.conf].concat(cv.lines)
        onExited: run.running = cv.users > 0
    }
    onUsersChanged: {
        if (users > 0 && !run.running && !write.running) write.running = true;
        else if (users === 0) run.running = false;
    }
    Process {
        id: run
        command: ["cava", "-p", cv.conf]
        stdout: SplitParser {
            onRead: line => {
                const v = line.split(";").filter(x => x !== "").map(x => Number(x) / 1000);
                if (v.length) cv.bars = v;
            }
        }
    }
}
