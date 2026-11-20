pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// A 10-band equaliser through EasyEffects: the bands are written as an output preset
// ("monolith") and loaded. Gains in dB, -12..12; kept in next.json.
Singleton {
    id: eq
    readonly property var freqs: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
    readonly property var presets: ({
        "Flat":   [0, 0, 0, 0, 0, 0, 0, 0, 0, 0],
        "Bass":   [6, 5, 4, 2, 0, 0, 0, 0, 0, 0],
        "Treble": [0, 0, 0, 0, 0, 1, 2, 4, 5, 6],
        "Vocal":  [-2, -2, -1, 1, 3, 4, 3, 1, 0, -1],
        "Rock":   [4, 3, 1, -1, -2, -1, 1, 3, 4, 4],
        "Electronic": [5, 4, 1, 0, -2, 1, 0, 2, 4, 5]
    })
    readonly property var gains: Store.get("eq.gains", presets.Flat)
    readonly property string preset: Store.get("eq.preset", "Flat")
    readonly property bool enabled: Store.get("eq.enabled", false)
    readonly property string file: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/easyeffects/output/monolith.json"

    function setBand(i, db) {
        const g = gains.slice();
        g[i] = Math.max(-12, Math.min(12, Math.round(db * 2) / 2));
        Store.set("eq.gains", g);
        Store.set("eq.preset", "Custom");
        // (setting it up means wanting to hear it: with the switch off, picking Bass or
        // dragging a band changed nothing you could hear)
        if (!enabled) Store.set("eq.enabled", true);
        applyLater.restart();
    }
    function usePreset(name) {
        Store.set("eq.gains", presets[name].slice());
        Store.set("eq.preset", name);
        if (!enabled) Store.set("eq.enabled", true);
        applyLater.restart();
    }
    function setEnabled(on) { Store.set("eq.enabled", on); applyLater.restart(); }

    Timer { id: applyLater; interval: 250; onTriggered: eq.apply() }

    // EasyEffects' equaliser is LSP's, loaded as an LV2 plugin. Without it (Gentoo builds
    // lsp-plugins as VST3 only unless asked) EasyEffects takes the preset and does nothing,
    // so the bands moved and nothing could be heard. `missing`: say so instead
    property bool missing: false
    property bool noApp: false
    Process {
        id: look
        running: true
        command: ["sh", "-c", "command -v easyeffects >/dev/null || { echo app; exit; }; "
            + "for d in ${LV2_PATH:-} \"$HOME/.lv2\" /usr/lib64/lv2 /usr/lib/lv2 /usr/local/lib64/lv2 /usr/local/lib/lv2 /usr/lib/x86_64-linux-gnu/lv2; do "
            + "[ -n \"$d\" ] && ls -d \"$d\"/lsp-plugins*.lv2 >/dev/null 2>&1 && { echo ok; exit; }; done; echo lv2"]
        stdout: StdioCollector { onStreamFinished: { const t = text.trim(); eq.noApp = t === "app"; eq.missing = t === "lv2"; } }
    }
    function recheck() { look.running = true; }

    function band(i, g) {
        return { "frequency": freqs[i], "gain": eq.enabled ? g : 0, "mode": "RLC (BT)", "mute": false,
                 "q": 1.5, "slope": "x1", "solo": false, "type": "Bell" };
    }
    function apply() {
        const left = {}, right = {};
        for (let i = 0; i < 10; i++) { left["band" + i] = band(i, gains[i]); right["band" + i] = band(i, gains[i]); }
        const preset = { "output": {
            "blocklist": [], "plugins_order": ["equalizer#0"],
            "equalizer#0": { "balance": 0.0, "bypass": !eq.enabled, "input-gain": 0.0, "output-gain": 0.0,
                             "mode": "IIR", "num-bands": 10, "split-channels": false,
                             "pitch-left": 0.0, "pitch-right": 0.0, "left": left, "right": right } } };
        writer.command = ["sh", "-c", "mkdir -p \"$(dirname \"$1\")\" && printf '%s' \"$2\" > \"$1\" && "
            + "(pgrep -x easyeffects >/dev/null || (setsid -f easyeffects --gapplication-service >/dev/null 2>&1; sleep 1)) && "
            + "easyeffects -l monolith", "_", eq.file, JSON.stringify(preset)];
        writer.running = true;
    }
    Process { id: writer }
}
