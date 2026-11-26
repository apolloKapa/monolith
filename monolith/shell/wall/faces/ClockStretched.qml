import QtQuick
import QtQuick.Shapes
import "../../core"
import "../../ui"

// Stretched: the time as tall, narrow digits drawn with one thick pen (round ends, round joins),
// the colon as two dots, together as wide as the widget allows. When a digit changes, the old one
// drops away and fades while the new one comes down into place.
FaceBase {
    id: face
    clip: true
    // the room: 94 % of the height; a digit is at most a third as wide as it is tall, and the
    // four digits, the colon (0.4 of a digit) and the four gaps (0.12 each) share 94 % of the width
    readonly property real tallness: Math.max(1, height * 0.94)
    readonly property real digitW: Math.max(1, Math.min(tallness * 0.32, width * 0.94 / 4.88))
    readonly property real pen: digitW * 0.24
    readonly property string shown: Qt.formatTime(face.now, "HH:mm")
    // the digits are drawn fully opaque in one layer and made see-through as a whole, so where a
    // digit's strokes cross (the 4, the 8, the middle of the 3) there's no brighter seam
    readonly property color opaqueInk: Qt.rgba(face.mainC.r, face.mainC.g, face.mainC.b, 1)

    // A digit as a path, in a box w wide and h tall drawn with a pen p wide: a tiny builder that
    // writes SVG path data (move, line, horizontal/vertical runs, quarter arcs, a curve).
    function digitPath(d, w, h, p) {
        const L = p / 2, R = w - p / 2, T = p / 2, B = h - p / 2, M = h / 2, rad = (R - L) / 2;
        const out = [];
        const go = (x, y) => out.push("M" + x + " " + y);
        const line = (x, y) => out.push("L" + x + " " + y);
        const across = x => out.push("H" + x);
        const down = y => out.push("V" + y);
        const bend = (x, y, ccw) => out.push("A" + rad + " " + rad + " 0 0 " + (ccw ? 0 : 1) + " " + x + " " + y);
        const curve = (ax, ay, bx, by, x, y) => out.push("C" + ax + " " + ay + " " + bx + " " + by + " " + x + " " + y);
        // a rounded box from (x0, y0) to (x1, y1), clockwise from the top edge
        const capsule = (x0, y0, x1, y1) => { go(x0 + rad, y0); across(x1 - rad); bend(x1, y0 + rad); down(y1 - rad); bend(x1 - rad, y1);
                                              across(x0 + rad); bend(x0, y1 - rad); down(y0 + rad); bend(x0 + rad, y0); out.push("Z"); };
        const dome = () => { go(L, T + rad); bend(R, T + rad); };          // the arch over a 2 or a 3
        const belly = M + h * 0.04;                                        // where a 5's and 6's bowl starts
        switch (d) {
        case "0": capsule(L, T, R, B); break;
        case "1": go(L, T + rad); line(R, T); down(B); break;
        case "2": { const pull = (B - T - rad) * 0.45; dome(); curve(R, T + rad + pull, L, B - pull, L, B); across(R); break; }
        case "3": dome(); down(M - rad); bend(R - rad, M); across(L + rad * 0.3); go(R - rad, M); bend(R, M + rad); down(B - rad); bend(L, B - rad); break;
        // one stroke: up the stem, down the slant, along the bar (three separate ones left seams)
        case "4": { const stem = L + (R - L) * 0.68; go(stem, B); down(T); line(L, T + (B - T) * 0.7); across(R); break; }
        case "5": go(R, T); across(L); down(belly); across(R - rad); bend(R, belly + rad); down(B - rad); bend(R - rad, B); across(L); break;
        // (a 9 is a 6 turned over: the cell is rotated)
        case "6": case "9": go(R, T); across(L + rad); bend(L, T + rad, true); down(B - rad); bend(L + rad, B, true); across(R - rad);
                            bend(R, B - rad, true); down(belly + rad); bend(R - rad, belly, true); across(L); break;
        case "7": go(L, T); across(R); line(L + (R - L) * 0.3, B - rad * 0.6); down(B); break;
        case "8": capsule(L, T, R, M); capsule(L, M, R, B); break;
        }
        return out.join(" ");
    }

    // one digit's drawing, slid by `drop` (in pens) and faded to `alpha`
    component Stroke: Shape {
        id: stroke
        property string digit: ""
        property real drop: 0
        property real alpha: 1
        anchors.fill: parent
        visible: digit !== "" && alpha > 0.001
        opacity: alpha
        rotation: digit === "9" ? 180 : 0
        transform: Translate { y: drop * face.pen * 0.8 }
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeWidth: face.pen
            strokeColor: face.opaqueInk
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg { path: face.digitPath(stroke.digit, stroke.width, stroke.height, face.pen) }
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: face.digitW * 0.12
        opacity: 0.85 * face.mainC.a
        layer.enabled: true
        layer.smooth: true
        // (one box per position, not per character: a box stays while its digit changes)
        Repeater {
            model: 5
            Item {
                id: slot
                required property int index
                readonly property string now: face.shown.charAt(index)
                readonly property bool dots: index === 2
                width: dots ? face.digitW * 0.4 : face.digitW
                height: face.tallness
                // the digit on show, the one it's leaving, and how far through (0 → 1)
                property string showing: now
                property string leaving: ""
                property real k: 1
                onNowChanged: { leaving = showing; showing = now; swap.restart(); }
                NumberAnimation on k { id: swap; running: false; from: 0; to: 1; duration: Theme.ms(520); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve }
                Stroke { digit: slot.dots ? "" : slot.leaving; alpha: 1 - slot.k; drop: slot.k }
                Stroke { digit: slot.dots ? "" : slot.showing; alpha: slot.k; drop: slot.k - 1 }
                // the colon: two dots, a third and two thirds of the way down
                Repeater {
                    model: slot.dots ? [0.35, 0.65] : []
                    Rectangle {
                        required property real modelData
                        width: face.pen * 1.1
                        height: width
                        radius: width / 2
                        color: face.opaqueInk
                        x: (slot.width - width) / 2
                        y: slot.height * modelData - height / 2
                    }
                }
            }
        }
    }
}
