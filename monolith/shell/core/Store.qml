pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The new shell's own settings and state, in ~/.config/monolith/next.json. get(path, fallback)
// reads ("idle.lockAfter"), set(path, value) writes (saved half a second later).
Singleton {
    id: store
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/monolith/next.json"
    property var data: ({})
    property int revision: 0
    property bool loaded: false

    function get(path, fallback) {
        let _ = revision;
        let cur = data;
        for (const k of path.split(".")) {
            if (cur === null || typeof cur !== "object" || !(k in cur)) return fallback;
            cur = cur[k];
        }
        return cur;
    }
    // whether a setting has been changed from its default (it's in the file at all)
    function has(path) {
        let _ = revision;
        let cur = data;
        for (const k of path.split(".")) {
            if (cur === null || typeof cur !== "object" || !(k in cur)) return false;
            cur = cur[k];
        }
        return true;
    }
    // back to the default: the setting leaves the file
    function unset(path) {
        if (!has(path)) return;
        const copy = JSON.parse(JSON.stringify(data));
        const keys = path.split(".");
        let cur = copy;
        for (let i = 0; i < keys.length - 1; i++) cur = cur[keys[i]];
        delete cur[keys[keys.length - 1]];
        data = copy;
        revision++;
        saveLater.restart();
    }
    function set(path, value) {
        const copy = JSON.parse(JSON.stringify(data));
        let cur = copy;
        const keys = path.split(".");
        for (let i = 0; i < keys.length - 1; i++) {
            if (typeof cur[keys[i]] !== "object" || cur[keys[i]] === null) cur[keys[i]] = {};
            cur = cur[keys[i]];
        }
        cur[keys[keys.length - 1]] = value;
        data = copy;
        revision++;
        saveLater.restart();
    }

    Timer { id: saveLater; interval: 500; onTriggered: fv.setText(JSON.stringify(store.data, null, 2) + "\n") }

    FileView {
        id: fv
        path: store.file
        atomicWrites: true
        printErrors: false
        onLoaded: { try { store.data = JSON.parse(text()); } catch (e) { store.data = {}; } store.revision++; store.loaded = true; }
        onLoadFailed: { store.data = {}; store.loaded = true; }
    }

    // `monolith set status.position '"bottom"'` (the value is JSON)
    IpcHandler {
        target: "store"
        function set(path: string, json: string): void { try { store.set(path, JSON.parse(json)); } catch (e) { store.set(path, json); } }
        function get(path: string): string { return JSON.stringify(store.get(path, null)); }
    }
}
