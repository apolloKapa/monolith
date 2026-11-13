pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Settings that live in niri's own config (displays, input, cursor, screenshot folder).
// Changes go through scripts/niri_conf.py one at a time, which edits only that line; niri
// reloads its config by itself. read(specs, cb) gives { "block|key": value-or-null }.
Singleton {
    id: nc
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri"
    readonly property string script: Qt.resolvedUrl("../scripts/niri_conf.py").toString().replace("file://", "")
    property var queue: []
    signal changed()

    function set(block, key, value) { push(["set", nc.dir, block, key, String(value)]); }
    function unset(block, key) { push(["unset", nc.dir, block, key]); }
    function flag(block, key, on) { push(["flag", nc.dir, block, key, on ? "on" : "off"]); }
    function quote(s) { return "\"" + String(s).replace(/\\/g, "\\\\").replace(/"/g, "\\\"") + "\""; }
    function unquote(v) { return v === null || v === undefined ? "" : String(v).replace(/^"(.*)"$/, "$1"); }

    function push(args) { queue = queue.concat([args]); if (!writer.running) next(); }
    function next() {
        if (queue.length === 0) { changed(); return; }
        writer.command = ["python3", nc.script].concat(queue[0]);
        queue = queue.slice(1);
        writer.running = true;
    }
    Process { id: writer; onExited: nc.next() }

    // reads: each caller gets its own process
    Component { id: readerC; Process { id: rp; property var cb; stdout: StdioCollector { onStreamFinished: { try { rp.cb(JSON.parse(text)); } catch (e) {} rp.destroy(); } } } }
    function read(specs, cb) {
        const p = readerC.createObject(nc, { cb: cb, command: ["python3", nc.script, "json", nc.dir].concat(specs) });
        p.running = true;
    }
}
