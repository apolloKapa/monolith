import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// What the Mouse and Keyboard pages read and change: scripts/peripherals.py edits niri's
// input { } section one setting at a time (niri applies each change at once) and prints the
// whole state back. Changes made while one is still being written wait their turn.
Item {
    id: cfg

    property var state: null
    property string error: ""
    property var pending: []

    function script() { return Caching.monolithDir + "/scripts/peripherals.py"; }

    function refresh() {
        if (!Caching.monolithDir) return;
        lister.running = false;
        lister.running = true;
    }

    function set(section, key, value) {
        // a newer value for the same setting replaces one still waiting
        let p = pending.filter(x => !(x[0] === section && x[1] === key));
        p.push([section, key, String(value)]);
        pending = p;
        next();
    }

    function next() {
        if (setter.running || pending.length === 0) return;
        const job = pending[0];
        pending = pending.slice(1);
        error = "";
        setter.command = ["python3", script(), "set"].concat(job);
        setter.running = true;
    }

    function take(text) {
        try { cfg.state = JSON.parse(text); } catch (e) {}
    }

    Process {
        id: lister
        command: ["python3", cfg.script(), "list"]
        stdout: StdioCollector { onStreamFinished: cfg.take(this.text) }
    }

    Process {
        id: setter
        stdout: StdioCollector { id: setterOut }
        stderr: StdioCollector { id: setterErr }
        onExited: function(code) {
            if (code === 0) {
                cfg.take(setterOut.text);
            } else {
                cfg.error = setterErr.text.trim() || "Couldn't change that setting";
                cfg.refresh();
            }
            cfg.next();
        }
    }

    Component.onCompleted: refresh()
}
