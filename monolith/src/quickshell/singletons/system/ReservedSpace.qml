pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// What Monolith's own panels (bar, frame, dock, island) take off each screen edge, kept in
// $XDG_RUNTIME_DIR/monolith/reserved.json as { "DP-1": { "top": 40, "left": 8, ... } }.
// niri reports no position for tiled or fullscreen windows; the Settings app works out where it
// is from this (the area windows tile in) and the tile sizes niri does report, for its glass.
Item {
    id: root

    property var entries: ({})
    property int seq: 0

    function newKey() {
        root.seq++;
        return "r" + root.seq;
    }

    function report(key, screenName, edge, size) {
        const cur = root.entries[key];
        if (size > 0 && screenName !== "" && edge !== "") {
            if (cur && cur.screen === screenName && cur.edge === edge && cur.size === size) return;
            root.entries[key] = { "screen": screenName, "edge": edge, "size": size };
        } else {
            if (!cur) return;
            delete root.entries[key];
        }
        writeTimer.restart();
    }

    Timer {
        id: writeTimer
        interval: 150
        onTriggered: {
            let out = {};
            for (const k in root.entries) {
                const e = root.entries[k];
                if (!out[e.screen]) out[e.screen] = { "top": 0, "bottom": 0, "left": 0, "right": 0 };
                out[e.screen][e.edge] += e.size;
            }
            file.setText(JSON.stringify(out));
        }
    }

    FileView {
        id: file
        path: Caching.getRunDir("monolith") + "/reserved.json"
    }
}
