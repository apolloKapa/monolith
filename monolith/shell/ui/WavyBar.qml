import QtQuick
import QtQuick.Shapes
import "../core"

// A line that waves (Settings → Styles → Wavy lines, Theme.wavy): the part from `from` to `to`
// (fractions of its length) is a wave in `color`, the rest a straight line in `trackColor`
// (`track: false` leaves that out: a divider, a line running out). Lies along its width, or
// its height (`vertical`), through the middle of the other side; the wave reaches a little
// past the item's own box. `gap`: pixels left clear around `to`, for a handle sitting there.
// `moving`: the wave runs along (something playing); it stands still without animations.
Item {
    id: w
    property real from: 0
    property real to: 0
    property color color: Theme.accent
    property color trackColor: Theme.ringTrack
    property real thick: 4
    property bool vertical: false
    property bool track: true
    property bool moving: false
    property real gap: 0
    readonly property real len: vertical ? height : width
    readonly property real mid: (vertical ? width : height) / 2
    readonly property real amp: Math.max(1.5, Math.min(4, thick * 0.8))
    readonly property real wl: Math.max(18, Math.min(36, thick * 8))
    readonly property real lo: Math.max(0, Math.min(1, Math.min(from, to))) * len
    readonly property real hi: Math.max(0, Math.min(1, Math.max(from, to))) * len
    // (the handle is at `to`: the wave stops short of it, and the straight part starts after it)
    readonly property bool toIsHi: to >= from
    readonly property real waveA: toIsHi ? lo : Math.min(hi, lo + gap)
    readonly property real waveB: toIsHi ? Math.max(lo, hi - gap) : hi
    readonly property real restA: toIsHi ? lo : lo - gap      // the straight line before the wave ends here
    readonly property real restB: toIsHi ? hi + gap : hi      // and the one after starts here
    property real phase: 0
    FrameAnimation {
        running: w.moving && w.visible && Theme.animOn && w.waveB - w.waveA > 1
        onTriggered: w.phase = (w.phase + frameTime * 2.6) % (2 * Math.PI)
    }
    function pt(along, across) { return vertical ? Qt.point(across, along) : Qt.point(along, across); }
    readonly property var pts: {
        const a = waveA, b = waveB, out = [];
        if (!visible || b - a < 1) return [pt(a, mid), pt(a, mid)];
        // (flat at both ends, so it meets its round caps and the handle straight)
        const edge = Math.min(10, (b - a) / 2), k2 = 2 * Math.PI / wl;
        for (let x = a; ; x += 2) {
            const xx = Math.min(x, b);
            const k = Math.min(1, (xx - a) / edge, (b - xx) / edge);
            out.push(pt(xx, mid + amp * k * Math.sin(xx * k2 - phase)));
            if (xx >= b) break;
        }
        return out;
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: w.track && w.restA > 1 ? w.trackColor : "transparent"
            strokeWidth: w.thick; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: w.vertical ? w.mid : 0; startY: w.vertical ? 0 : w.mid
            PathLine { x: w.vertical ? w.mid : Math.max(0, w.restA); y: w.vertical ? Math.max(0, w.restA) : w.mid }
        }
        ShapePath {
            strokeColor: w.track && w.len - w.restB > 1 ? w.trackColor : "transparent"
            strokeWidth: w.thick; fillColor: "transparent"; capStyle: ShapePath.RoundCap
            startX: w.vertical ? w.mid : Math.min(w.len, w.restB); startY: w.vertical ? Math.min(w.len, w.restB) : w.mid
            PathLine { x: w.vertical ? w.mid : w.len; y: w.vertical ? w.len : w.mid }
        }
        ShapePath {
            strokeColor: w.waveB - w.waveA >= 1 ? w.color : "transparent"
            strokeWidth: w.thick; fillColor: "transparent"
            capStyle: ShapePath.RoundCap; joinStyle: ShapePath.RoundJoin
            PathPolyline { path: w.pts }
        }
    }
}
