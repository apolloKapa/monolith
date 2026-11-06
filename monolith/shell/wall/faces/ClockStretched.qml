import QtQuick
import QtQuick.Shapes
import "../../core"
import "../../ui"

// Stretched: HH:MM drawn as thick rounded strokes, each digit built from lines and arcs, tall and
// narrow, filling the widget's width.
FaceBase {
    id: f
    clip: true
    readonly property real areaH: Math.max(1, height * 0.94)
    readonly property real gapR: 0.12
    readonly property real colonR: 0.4
    readonly property real cw: Math.max(1, Math.min(areaH * 0.32, width * 0.94 / (4 + colonR + 4 * gapR)))
    readonly property real gap: cw * gapR
    readonly property real stroke: cw * 0.24
    readonly property var chars: Qt.formatTime(f.now, "HH:mm").split("")

    function rr(x0, y0, x1, y1, r) {
        return `M${x0 + r} ${y0} H${x1 - r} A${r} ${r} 0 0 1 ${x1} ${y0 + r} V${y1 - r} A${r} ${r} 0 0 1 ${x1 - r} ${y1} H${x0 + r} A${r} ${r} 0 0 1 ${x0} ${y1 - r} V${y0 + r} A${r} ${r} 0 0 1 ${x0 + r} ${y0} Z`;
    }
    // each digit as an SVG path in a w×h cell, strokes `s` wide
    function glyph(ch, w, h, s) {
        const x0 = s / 2, x1 = w - s / 2, y0 = s / 2, y1 = h - s / 2, ym = h / 2, r = (x1 - x0) / 2;
        const top = `M${x0} ${y0 + r} A${r} ${r} 0 0 1 ${x1} ${y0 + r}`;
        switch (ch) {
        case "0": return rr(x0, y0, x1, y1, r);
        case "1": return `M${x0} ${y0 + r} L${x1} ${y0} V${h}`;
        case "2": { const d = (y1 - y0 - r) * 0.45; return `${top} C${x1} ${y0 + r + d} ${x0} ${y1 - d} ${x0} ${y1} H${x1}`; }
        case "3": return `${top} V${ym - r} A${r} ${r} 0 0 1 ${x1 - r} ${ym} H${x0 + r * 0.3} M${x1 - r} ${ym} A${r} ${r} 0 0 1 ${x1} ${ym + r} V${y1 - r} A${r} ${r} 0 0 1 ${x0} ${y1 - r}`;
        case "4": { const xs = x0 + (x1 - x0) * 0.68, yb = y0 + (y1 - y0) * 0.7; return `M${xs} ${h} V0 M${xs} ${s * 0.2} L${x0} ${yb} M0 ${yb} H${w}`; }
        case "5": { const yq = ym + 0.04 * h; return `M${x1} ${y0} H${x0} V${yq} H${x1 - r} A${r} ${r} 0 0 1 ${x1} ${yq + r} V${y1 - r} A${r} ${r} 0 0 1 ${x1 - r} ${y1} H${x0}`; }
        case "6": case "9": { const yq = ym + 0.04 * h; return `M${x1} ${y0} H${x0 + r} A${r} ${r} 0 0 0 ${x0} ${y0 + r} V${y1 - r} A${r} ${r} 0 0 0 ${x0 + r} ${y1} H${x1 - r} A${r} ${r} 0 0 0 ${x1} ${y1 - r} V${yq + r} A${r} ${r} 0 0 0 ${x1 - r} ${yq} H${x0}`; }
        case "7": return `M0 ${y0} H${x1} L${x0 + (x1 - x0) * 0.3} ${y1} V${h}`;
        case "8": return rr(x0, y0, x1, ym, r) + " " + rr(x0, ym, x1, y1, r);
        }
        return "";
    }
    Row {
        anchors.centerIn: parent
        spacing: f.gap
        opacity: 0.85
        Repeater {
            model: f.chars
            Item {
                id: cell
                required property string modelData
                readonly property bool colon: modelData === ":"
                width: colon ? f.cw * f.colonR : f.cw
                height: f.areaH
                Shape {
                    anchors.fill: parent
                    visible: !cell.colon
                    rotation: cell.modelData === "9" ? 180 : 0
                    preferredRendererType: Shape.CurveRenderer
                    ShapePath {
                        strokeWidth: f.stroke
                        strokeColor: Theme.text
                        fillColor: "transparent"
                        capStyle: ShapePath.FlatCap
                        joinStyle: ShapePath.RoundJoin
                        PathSvg { path: f.glyph(cell.modelData, cell.width, cell.height, f.stroke) }
                    }
                }
                Repeater {
                    model: cell.colon ? 2 : 0
                    Rectangle {
                        required property int index
                        width: f.stroke * 1.1; height: width; radius: width / 2
                        color: Theme.text
                        x: (cell.width - width) / 2
                        y: cell.height * (index === 0 ? 0.35 : 0.65) - height / 2
                    }
                }
            }
        }
    }
}
