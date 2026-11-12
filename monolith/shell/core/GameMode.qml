pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Game mode: the performance power profile, do not disturb, the screen kept awake and (if
// you like) the island tucked away. Turning it off puts each one back the way it was.
// Also the performance overlay (status/PerfOverlay.qml) and ending a stuck game.
// The way things were is kept in Store (gaming.session) while it's on, so a shell restart or
// an update in the middle of a game still knows it's on and can put everything back.
Singleton {
    id: gm
    property bool active: false
    property var before: ({})
    readonly property bool overlay: Store.get("gaming.overlay", false) === true
    readonly property bool hideIsland: Store.get("gaming.hideIsland", false) === true

    function toggle() { active ? stop() : start(); }
    function start() {
        if (active) return;
        profileGet.running = true;      // remembers it, then switches to performance
        before = { dnd: Notifs.dnd, awake: Tasks.awake, autohide: Store.get("status.autohide", false), hid: hideIsland };
        Notifs.dnd = true;
        Tasks.awake = true;
        if (hideIsland) Store.set("status.autohide", true);
        active = true;
        Store.set("gaming.session", before);
    }
    function stop() {
        if (!active) return;
        Notifs.dnd = before.dnd === true;
        Tasks.awake = before.awake === true;
        if (before.hid === true || (before.hid === undefined && hideIsland)) Store.set("status.autohide", before.autohide === true);
        if (before.profile) Quickshell.execDetached(["powerprofilesctl", "set", before.profile]);
        active = false;
        Store.unset("gaming.session");
    }
    // back after a restart: still on, with what to put back
    Connections {
        target: Store
        function onLoadedChanged() { gm.resume(); }
    }
    Component.onCompleted: resume()
    function resume() {
        if (!Store.loaded || active) return;
        const b = Store.get("gaming.session", null);
        if (!b || typeof b !== "object") return;
        before = b;
        active = true;
        Tasks.awake = true;           // (not saved by itself)
    }
    Process {
        id: profileGet
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                // (turned off again before the answer came: nothing to switch)
                if (!gm.active) return;
                const b = Object.assign({}, gm.before); b.profile = text.trim(); gm.before = b;
                Store.set("gaming.session", b);
                Quickshell.execDetached(["powerprofilesctl", "set", "performance"]);
            }
        }
    }

    // end the focused window's program at once (a game that stopped answering)
    function killFocused() {
        const w = Niri.focusedWindow;
        if (w && w.pid) Quickshell.execDetached(["kill", "-9", String(w.pid)]);
    }

    IpcHandler {
        target: "gaming"
        function toggle(): void { gm.toggle(); }
        function overlay(): void { Store.set("gaming.overlay", !gm.overlay); }
    }
}
