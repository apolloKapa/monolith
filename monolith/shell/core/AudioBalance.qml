pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire

// Left/right balance for the default output, kept per output in next.json
// ("audio.balance": { node name: -1 all left .. 1 all right }).
//
// It's applied as the node's software volumes (softVolumes), not its channel volumes:
// some devices (UCM "split" ones, like Audient's EVO4) flatten uneven channel volumes back
// to their average, through Quickshell and pactl alike, so a balance set that way snapped
// straight back to centre. The software volumes are applied by PipeWire itself on every
// device, but PipeWire works them out again whenever the volume changes, so they're put
// back each time: read the node's current ones (pw-dump), scale one side, write (pw-cli).
Singleton {
    id: bal
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property string key: sink ? sink.name : ""
    readonly property real value: {
        const all = Store.get("audio.balance", ({}));
        return key !== "" && all && typeof all[key] === "number" ? all[key] : 0;
    }

    PwObjectTracker { objects: bal.sink ? [bal.sink] : [] }

    function set(b) {
        if (key === "") return;
        b = Math.max(-1, Math.min(1, b));
        if (Math.abs(b) < 0.02) b = 0;
        const all = Object.assign({}, Store.get("audio.balance", ({})));
        if (b === 0) delete all[key];
        else all[key] = Math.round(b * 100) / 100;
        Store.set("audio.balance", all);
        check(20);
    }

    // the quieter side's gain, cubed like the volume slider: 50% right = the left at half volume
    function sideGains() {
        return [value > 0 ? Math.pow(1 - value, 3) : 1, value < 0 ? Math.pow(1 + value, 3) : 1];
    }
    // which side a channel is on: by its position (FL, RL, SL, FLC…; centre and LFE stay put),
    // or for unnamed channels (AUX0, AUX1…) of a two-channel node, left then right
    readonly property var lefts: ["FL", "RL", "SL", "FLC", "RLC", "TFL", "TRL", "TSL", "FLW", "FLH"]
    readonly property var rights: ["FR", "RR", "SR", "FRC", "RRC", "TFR", "TRR", "TSR", "FRW", "FRH"]
    function side(pos, i, n) {
        if (lefts.indexOf(pos) >= 0) return 0;
        if (rights.indexOf(pos) >= 0) return 1;
        return n === 2 && !/^(MONO|FC|LFE|RC|TC|TFC|TRC)$/.test(pos) ? i : -1;
    }

    // what was written last, per node id: { base: PipeWire's own values, wrote: ours }
    property var state: ({})
    function same(a, b) {
        if (!a || !b || a.length !== b.length) return false;
        for (let i = 0; i < a.length; i++) if (Math.abs(a[i] - b[i]) > 1e-5) return false;
        return true;
    }
    function applyFrom(id, props) {
        const soft = props.softVolumes, map = props.channelMap || [];
        if (!Array.isArray(soft) || soft.length === 0) return;
        const st = state[id];
        // never touched and nothing to do: leave PipeWire's (or pavucontrol's) values alone
        if (!st && value === 0) return;
        // still ours: the base is what PipeWire had; otherwise PipeWire just set fresh ones
        const base = st && same(soft, st.wrote) ? st.base : soft.slice();
        const g = sideGains();
        const want = base.map((v, i) => { const s = side(map[i], i, soft.length); return s < 0 ? v : v * g[s]; });
        const next = Object.assign({}, state);
        if (value === 0) delete next[id];
        else next[id] = { base: base, wrote: want.map(w => Number(w.toFixed(6))) };
        state = next;
        if (same(want, soft)) return;
        setter.command = ["pw-cli", "s", String(id), "Props", "{ softVolumes: [ " + want.map(w => w.toFixed(6)).join(", ") + " ] }"];
        setter.running = true;
    }

    // ── when to look: the volume or mute changed (PipeWire redid its values), the output
    // changed, or the balance did. Twice, in case the software volumes land a moment later ──
    function check(delay) { soon.interval = delay || 60; soon.restart(); again.restart(); }
    Timer { id: soon; onTriggered: bal.read() }
    Timer { id: again; interval: 500; onTriggered: bal.read() }
    Connections {
        target: bal.sink && bal.sink.audio ? bal.sink.audio : null
        function onVolumesChanged() { bal.check(); }
        function onMutedChanged() { bal.check(); }
    }
    Connections {
        target: bal.sink
        function onReadyChanged() { bal.check(); }
    }
    onSinkChanged: check()
    onValueChanged: check(20)
    Component.onCompleted: check(300)

    property bool pending: false
    property int readingId: -1
    function read() {
        if (!sink || !sink.ready) return;
        if (reader.running) { pending = true; return; }
        readingId = sink.id;
        reader.command = ["pw-dump", String(sink.id)];
        reader.running = true;
    }
    Process {
        id: reader
        stdout: StdioCollector {
            onStreamFinished: {
                let objs = [];
                try { objs = JSON.parse(text); } catch (e) { return; }
                for (const o of objs || []) {
                    const ps = o && o.info && o.info.params && o.info.params.Props;
                    if (!Array.isArray(ps)) continue;
                    const p = ps.find(x => x && Array.isArray(x.softVolumes));
                    if (p) { if (bal.sink && bal.sink.id === bal.readingId) bal.applyFrom(bal.readingId, p); return; }
                }
            }
        }
        onExited: if (bal.pending) { bal.pending = false; bal.read(); }
    }
    Process { id: setter }
}
