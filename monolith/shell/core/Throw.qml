pragma Singleton
import QtQuick
import Quickshell

// Notifications thrown away (Settings → Notifications → "Thrown away": Fall). A thrown card
// is a snapshot that falls down its screen like a ball: it keeps the throw's speed sideways,
// gravity pulls it down, it spins, bounces off the screen's sides and drops out at the bottom.
// status/Thrown.qml draws them, one full-screen click-through layer per screen.
Singleton {
    id: th
    readonly property bool on: Store.get("notifications.throw", "slide") === "fall" && Theme.animOn
    // live throws: { id, screen, url, x, y, w, h, vx, vy, spin } (screen coordinates, px/s)
    property var flying: []
    property int seq: 0
    function launch(screen, url, x, y, w, h, vx, vy) {
        seq++;
        const spin = Math.max(-720, Math.min(720, vx * 0.35 + (Math.random() - 0.5) * 120));
        flying = flying.concat([{ id: seq, screen: screen, url: url, x: x, y: y, w: w, h: h, vx: vx, vy: vy, spin: spin }]);
    }
    function land(id) { flying = flying.filter(f => f.id !== id); }
    function on_(screen) { return flying.filter(f => f.screen === screen); }
}
