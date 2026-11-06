pragma Singleton
import QtQuick
import Quickshell

// Interface sounds (Settings → Notifications → Interface sounds): soft blips for clicks, switches,
// menus opening and closing, and dropping things; made by tools/make_sounds.py, played with
// pw-play as "event" sounds at their own volume. Off unless switched on.
Singleton {
    id: snd
    readonly property bool on: Store.get("sounds.enabled", false) === true
    readonly property real volume: Math.max(0, Math.min(1, Number(Store.get("sounds.volume", 0.5))))
    readonly property string dir: Qt.resolvedUrl("../sounds").toString().replace(/^file:\/\//, "")
    // a burst of clicks plays once
    property real last: 0
    function play(name) {
        if (!on || volume <= 0) return;
        const now = Date.now();
        if (now - last < 40) return;
        last = now;
        Quickshell.execDetached(["pw-play", "--media-role", "Notification", "--volume", String(volume),
            "-P", "{ \"application.name\": \"Monolith sounds\", \"media.role\": \"event\" }", dir + "/" + name + ".wav"]);
    }
}
