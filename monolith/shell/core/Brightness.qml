pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Screen brightness: a laptop's backlight (brightnessctl), or on a desktop each monitor's own
// brightness over DDC/CI (ddcutil: the same as its buttons). The brightness keys, the control
// center's slider and `monolith brightness up|down|<0-100>` all come here; a change made that way
// shows the pop-up (status/Osd), like the volume.
Singleton {
    id: br
    // "backlight" | "ddc" | "" (none found yet / nothing to change)
    property string mode: ""
    // DDC monitors: [{ name: "DP-1", bus: "11", value: 0..100 }]
    property var displays: []
    property real backlight: -1                 // 0..1
    readonly property bool available: mode !== ""
    // what the slider and the pop-up show: the focused screen's (DDC), else the first
    readonly property real level: {
        if (mode === "backlight") return Math.max(0, backlight);
        if (mode !== "ddc" || !displays.length) return 0;
        const d = displays.find(x => x.name === Niri.focusedOutput) || displays[0];
        return d.value / 100;
    }
    // a change made from here (keys, slider, command): the pop-up shows it
    signal changed()

    Component.onCompleted: detect.running = true
    Process {
        id: detect
        command: ["sh", "-c", "brightnessctl -c backlight -m 2>/dev/null | head -1 | cut -d, -f4"]
        stdout: StdioCollector {
            onStreamFinished: {
                const v = parseInt(text);
                if (!isNaN(v)) { br.backlight = v / 100; br.mode = "backlight"; return; }
                ddcFind.running = true;
            }
        }
    }
    // the monitors that answer over DDC/CI, and which screen each is
    Process {
        id: ddcFind
        command: ["sh", "-c", "command -v ddcutil >/dev/null && ddcutil detect --brief 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = [];
                for (const block of text.split(/\n\s*\n/)) {
                    if (!/^Display \d/m.test(block)) continue;          // ("Invalid display": no DDC)
                    const bus = (block.match(/I2C bus:\s*\/dev\/i2c-(\d+)/) || [])[1];
                    const con = (block.match(/DRM connector:\s*card\d+-(\S+)/) || [])[1];
                    if (bus && con) out.push({ name: con, bus: bus, value: 50 });
                }
                br.displays = out;
                if (out.length) { br.mode = "ddc"; br.readAll(); }
            }
        }
    }
    // each monitor's brightness now (after it was changed on the monitor itself, too)
    function readAll() {
        if (mode !== "ddc" || reader.running) return;
        reader.command = ["sh", "-c", displays.map(d => "printf '%s ' " + d.bus + "; ddcutil --bus " + d.bus + " getvcp 10 --brief 2>/dev/null || echo").join("; ")];
        reader.running = true;
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                const list = br.displays.slice();
                for (const line of text.split("\n")) {
                    const m = line.match(/^(\d+) VCP 10 C (\d+) (\d+)/);
                    if (!m) continue;
                    const i = list.findIndex(d => d.bus === m[1]);
                    if (i >= 0 && !br.pending[m[1]]) list[i] = Object.assign({}, list[i], { value: Math.round(100 * Number(m[2]) / Math.max(1, Number(m[3]))) });
                }
                br.displays = list;
            }
        }
    }

    // ── changing it ──
    // all screens by `d` points (keys), or set to a value (0..100); `name`: one screen only
    function step(d) { change(null, d, true); }
    function set(v, name) { change(name || null, v, false); }
    function change(name, v, relative) {
        if (mode === "backlight") {
            const nv = Math.max(1, Math.min(100, Math.round(relative ? backlight * 100 + v : v)));
            backlight = nv / 100;
            Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", nv + "%"]);
        } else if (mode === "ddc") {
            const list = displays.map(x => {
                if (name && x.name !== name) return x;
                const nv = Math.max(0, Math.min(100, Math.round(relative ? x.value + v : v)));
                send(x.bus, nv);
                return Object.assign({}, x, { value: nv });
            });
            displays = list;
        } else return;
        changed();
    }
    // DDC is slow (a tenth of a second or so each): one write at a time, the monitors one after
    // the other (written at once, the second monitor ignored its write), and only the latest value
    // (a dragged slider or a held key sends many)
    property var pending: ({})                  // bus -> value still to send
    function send(bus, v) {
        const p = Object.assign({}, pending); p[bus] = v; pending = p;
        if (!writer.running) flush();
    }
    function flush() {
        const buses = Object.keys(pending);
        if (!buses.length) return;
        const p = pending; pending = ({});
        writer.command = ["sh", "-c", buses.map(b => "ddcutil --bus " + b + " --noverify setvcp 10 " + p[b] + " >/dev/null 2>&1").join("; ")];
        writer.running = true;
    }
    Process { id: writer; onExited: br.flush() }

    // `monolith brightness up | down | <0-100>`, and the brightness keys
    IpcHandler {
        target: "brightness"
        function up(): void { br.step(5); }
        function down(): void { br.step(-5); }
        function set(v: int): void { br.set(v); }
        function get(): string { return br.available ? String(Math.round(br.level * 100)) : "none"; }
    }
}
