pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The quick access drawing (status/quick/Draw.qml): its strokes, where you're looking and how
// far zoomed in, undo / redo. Kept here so the drawing is still there when the panel closes
// (the tool itself is unloaded then), and saved to ~/.local/state/monolith/quick-draw.json so
// it survives a restart.
// A stroke: { t: pen | hl | line | arrow | rect | ellipse, c: colour, s: width, pts: [x, y, …] }
// in the drawing's own (endless) coordinates; the view shows from (ox, oy) at zoom z.
// A picture (pasted or dropped in): { t: "img", f: its copy in picDir, x, y, w, h }.
Singleton {
    id: sk
    // The whiteboard's keys: [id, what it does, its default keys]. Changed in Settings → Desktop →
    // Quick access (kept as quick.drawKeys: { id: "Ctrl+Z" }, "" for none); read here by the tool
    // (status/quick/Draw.qml) and by that settings page.
    readonly property var drawKeys: [
        ["undo", "Undo", ["Ctrl+Z"]], ["redo", "Redo", ["Ctrl+Y", "Ctrl+Shift+Z"]],
        ["copy", "Copy the drawing", ["Ctrl+C"]], ["paste", "Paste a picture", ["Ctrl+V"]], ["save", "Save to Pictures", ["Ctrl+S"]],
        ["selectAll", "Select everything", ["Ctrl+A"]], ["cut", "Remove what's picked", ["Ctrl+X"]], ["dup", "Duplicate picked picture", ["Ctrl+D"]],
        ["fit", "Fit it all in", ["Ctrl+0"]], ["zoomIn", "Zoom in", ["Ctrl+=", "Ctrl++"]], ["zoomOut", "Zoom out", ["Ctrl+-"]],
        ["thinner", "Thinner", ["["]], ["thicker", "Thicker", ["]"]],
        ["pen", "Pen", ["P"]], ["hl", "Highlighter", ["H"]], ["line", "Line", ["L"]], ["arrow", "Arrow", ["A"]], ["rect", "Rectangle", ["R"]],
        ["ellipse", "Ellipse", ["O"]], ["eraser", "Eraser", ["E"]], ["hand", "Move around", ["M"]], ["move", "Move pictures", ["V"]], ["pic", "Add a picture", ["I"]]
    ]
    function keysFor(id) {
        const set = (Store.get("quick.drawKeys", {}) || {})[id];
        if (typeof set === "string") return set === "" ? [] : [set];
        const k = drawKeys.find(x => x[0] === id);
        return k ? k[2] : [];
    }
    // as shown: "Ctrl + Z" ("" when it has no key)
    function keyText(id) { const k = keysFor(id); return k.length ? k[0].replace(/\+(?=.)/g, " + ") : ""; }
    property var strokes: []
    property real ox: 0
    property real oy: 0
    property real z: 1
    // every change bumps this (the pad repaints)
    property int rev: 0
    // undo: the drawing as it was before each change; redo: as it was before each undo
    property var past: []
    property var future: []
    readonly property bool canUndo: past.length > 0
    readonly property bool canRedo: future.length > 0
    // pictures in the drawing are copied here (so moving or deleting the original doesn't matter)
    readonly property string picDir: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/monolith/quick-draw"
    readonly property real minZ: 0.02
    readonly property real maxZ: 50

    // a change: the new list of strokes (the old one goes on the undo list)
    function commit(next) {
        past = past.concat([strokes]).slice(-200);
        future = [];
        strokes = next;
        changed();
    }
    function undo() { if (!past.length) return; future = future.concat([strokes]); strokes = past[past.length - 1]; past = past.slice(0, -1); changed(); }
    function redo() { if (!future.length) return; past = past.concat([strokes]); strokes = future[future.length - 1]; future = future.slice(0, -1); changed(); }
    function clear() { if (strokes.length) commit([]); }
    function changed() { rev++; saveSoon.restart(); }
    // the view moved (saved too, so it opens where you left it)
    function moved() { rev++; saveSoon.restart(); }

    FileView {
        id: fv
        path: (Quickshell.env("XDG_STATE_HOME") || (Quickshell.env("HOME") + "/.local/state")) + "/monolith/quick-draw.json"
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                sk.strokes = Array.isArray(d.strokes) ? d.strokes : [];
                sk.ox = Number(d.ox) || 0; sk.oy = Number(d.oy) || 0;
                sk.z = Math.max(sk.minZ, Math.min(sk.maxZ, Number(d.z) || 1));
                sk.rev++;
            } catch (e) {}
            // pictures nothing uses any more (deleted, cleared; undo doesn't outlive a restart)
            const used = sk.strokes.filter(x => x.t === "img").map(x => x.f.replace(/^.*\//, ""));
            tidy.command = ["sh", "-c", "cd \"$1\" 2>/dev/null || exit 0; shift; for f in *; do [ -f \"$f\" ] || continue; keep=0; for u; do [ \"$f\" = \"$u\" ] && keep=1; done; [ $keep = 1 ] || rm -f -- \"$f\"; done", "_", sk.picDir].concat(used);
            tidy.running = true;
        }
    }
    Process { id: tidy }
    Timer { id: saveSoon; interval: 800; onTriggered: fv.setText(JSON.stringify({ strokes: sk.strokes, ox: sk.ox, oy: sk.oy, z: sk.z })) }
}
