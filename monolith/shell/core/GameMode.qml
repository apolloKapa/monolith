pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Game mode: the performance power profile, do not disturb, the screen kept awake and (if
// you like) the island tucked away. Turning it off puts each one back the way it was.
// Also the performance overlay (status/PerfOverlay.qml) and ending a stuck game.
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
        before = { dnd: Notifs.dnd, awake: Tasks.awake, autohide: Store.get("status.autohide", false) };
        Notifs.dnd = true;
        Tasks.awake = true;
        if (hideIsland) Store.set("status.autohide", true);
        active = true;
    }
    function stop() {
        if (!active) return;
        Notifs.dnd = before.dnd === true;
        Tasks.awake = before.awake === true;
        if (hideIsland) Store.set("status.autohide", before.autohide === true);
        if (before.profile) Quickshell.execDetached(["powerprofilesctl", "set", before.profile]);
        active = false;
    }
    Process {
        id: profileGet
        command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]
        stdout: StdioCollector {
            onStreamFinished: {
                const b = Object.assign({}, gm.before); b.profile = text.trim(); gm.before = b;
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
