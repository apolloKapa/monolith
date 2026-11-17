pragma Singleton
import QtQuick
import Quickshell

// Notifications being swiped away. As soon as a swipe starts, the card hands itself over to
// status/Thrown.qml (one full-screen click-through layer per screen): a copy that follows the
// pointer there, so nothing cuts it off at the edge of the card's own little window. Let go:
//   theme (Settings → Notifications → "Thrown away": Theme, the default): it goes the way the
//        style makes things go (its CyberFx: Cyberpunk's Blackwall, Doodle's eraser…); a style
//        without its own effect slides it off
//   fall: it falls down its screen like a ball, as fast sideways as it was flicked, tossed up a
//        little, spinning, bouncing off the sides. Always, whatever the style
//   slide: it slides off the way it was flicked, fading. Always, whatever the style
//   not far or fast enough: it springs back, and the real card takes over again (home)
// The real card hides only once the copy is on screen (ready): no gap.
Singleton {
    id: th
    // what's picked (slide | fall | theme), and what that comes to with this style
    readonly property string picked: Store.get("notifications.throw", "theme")
    readonly property string mode: picked === "fall" ? "fall" : picked === "slide" ? "slide" : (Theme.cyber ? "theme" : "slide")
    readonly property bool on: Theme.animOn
    // live copies: { id, screen, url, x, y, w, h } (screen coordinates)
    property var flying: []
    property int seq: 0
    signal ready(int id)                       // the copy is on screen
    signal dragTo(int id, real dx)             // follow the pointer
    signal letGo(int id, real vx, real vy, string mode)
    signal springBack(int id)
    signal home(int id)                        // sprung back: the real card shows again
    signal drop(int id)                        // its card went on to another notification: it fades away
    // Clear: every card on screen is thrown at once, each its own way (ui/NotificationCard)
    signal scatter()
    property int scattered: 0                  // how many cards took part in the last one
    // `ink`: the card's press ripple as it was when grabbed ({ cx, cy, spread, alpha, color,
    // radius }), which the copy plays on (photographed, it froze half-grown), or null
    function launch(screen, url, x, y, w, h, ink) {
        seq++;
        flying = flying.concat([{ id: seq, screen: screen, url: url, x: x, y: y, w: w, h: h, ink: ink || null }]);
        return seq;
    }
    function land(id) { flying = flying.filter(f => f.id !== id); }
    function on_(screen) { return flying.filter(f => f.screen === screen); }
}
