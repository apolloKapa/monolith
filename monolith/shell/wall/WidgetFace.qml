import QtQuick
import Quickshell
import Quickshell.Services.Mpris
import "../core"

// One widget: loads its look from wall/faces/ (e.g. faces/ClockMaterial.qml) and gives it what it
// needs as `ctx`: the item (with its own settings), the time, the player, whether it's live
// (false in the editor's palette: no timers, no cava) and what's behind it for the glass blur.
// Used on the desktop, on the lock screen and in the widget editor; the caller sizes it.
Item {
    id: w
    property string type: item ? item.type : "clock"
    property string face: item ? (item.face || "") : ""
    property var item: null
    property bool live: true
    // what's behind it (the wallpaper item) and where this widget sits on it, for the glass
    property Item backdrop: null
    property point origin: Qt.point(x, y)

    readonly property var size: WidgetLayout.size(item || { type: type, face: face })
    implicitWidth: size[0]
    implicitHeight: size[1]
    opacity: opt("opacity", 1)

    function opt(k, d) { return WidgetLayout.opt(item, k, d); }

    // shared by every look
    property alias clock: sysClock
    SystemClock { id: sysClock; precision: SystemClock.Seconds; enabled: w.live }
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null
    // a playing track's position only updates when asked
    Timer { interval: 500; repeat: true; running: w.live && !!w.player && w.player.isPlaying && w.type === "media"; onTriggered: w.player.positionChanged() }

    Loader {
        id: body
        anchors.fill: parent
        readonly property var ctx: w
        source: WidgetLayout.file(w.type, w.face) !== "" ? "faces/" + WidgetLayout.file(w.type, w.face) + ".qml" : ""
    }
}
