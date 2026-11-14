pragma Singleton
import QtQuick
import Quickshell

// Notifications being swiped away. As soon as a swipe starts, the card hands itself over to
// status/Thrown.qml (one full-screen click-through layer per screen): a copy that follows the
// pointer there, so nothing cuts it off at the edge of the card's own little window. Let go:
//   fall (Settings → Notifications → "Thrown away": Fall): it falls down its screen like a ball,
//        as fast sideways as it was flicked, tossed up a little, spinning, bouncing off the sides
//   slide: it slides off the way it was flicked, fading
//   not far or fast enough: it springs back, and the real card takes over again (home)
// The real card hides only once the copy is on screen (ready): no gap.
Singleton {
    id: th
    readonly property string mode: Store.get("notifications.throw", "slide") === "fall" ? "fall" : "slide"
    readonly property bool on: Theme.animOn
    // live copies: { id, screen, url, x, y, w, h } (screen coordinates)
    property var flying: []
    property int seq: 0
    signal ready(int id)                       // the copy is on screen
    signal dragTo(int id, real dx)             // follow the pointer
    signal letGo(int id, real vx, real vy, string mode)
    signal springBack(int id)
    signal home(int id)                        // sprung back: the real card shows again
    // Clear: every card on screen is thrown at once, each its own way (ui/NotificationCard)
    signal scatter()
    property int scattered: 0                  // how many cards took part in the last one
    function launch(screen, url, x, y, w, h) {
        seq++;
        flying = flying.concat([{ id: seq, screen: screen, url: url, x: x, y: y, w: w, h: h }]);
        return seq;
    }
    function land(id) { flying = flying.filter(f => f.id !== id); }
    function on_(screen) { return flying.filter(f => f.screen === screen); }
}
