pragma Singleton
import QtQuick
import Quickshell

// Notifications swiped away. The card hands itself over to status/Thrown.qml, one full-screen
// click-through layer per screen, so nothing cuts it off at the edge of its own little window:
//   fall (Settings → Notifications → "Thrown away": Fall): it falls down its screen like a ball,
//        as fast sideways as it was flicked, tossed up a little, spinning, bouncing off the sides
//   slide: it slides off the way it was flicked, fading
// The card stays where it is until its copy is on screen (ready), then hides: no gap.
Singleton {
    id: th
    readonly property string mode: Store.get("notifications.throw", "slide") === "fall" ? "fall" : "slide"
    readonly property bool on: Theme.animOn
    // live throws: { id, screen, url, x, y, w, h, vx, vy, spin, mode } (screen coordinates, px/s)
    property var flying: []
    property int seq: 0
    signal ready(int id)
    function launch(screen, url, x, y, w, h, vx, vy) {
        seq++;
        const spin = mode === "fall" ? Math.max(-720, Math.min(720, vx * 0.35 + (Math.random() - 0.5) * 120)) : 0;
        flying = flying.concat([{ id: seq, screen: screen, url: url, x: x, y: y, w: w, h: h, vx: vx,
                                  vy: mode === "fall" ? vy : 0, spin: spin, mode: mode }]);
        return seq;
    }
    function land(id) { flying = flying.filter(f => f.id !== id); }
    function on_(screen) { return flying.filter(f => f.screen === screen); }
}
