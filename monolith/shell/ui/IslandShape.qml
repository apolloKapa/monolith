import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../core"

// The island's outline: a body `bodyW` × `height` hanging from the top edge, joined to the edge
// by a concave curve (`ear`) on each side, with round lower corners (`r`). The item is
// bodyW + 2·ear wide; the body sits between the ears. Filled, with a soft shadow under it
// (under the shape only; its children aren't layered).
Item {
    id: s
    property real bodyW: 400
    property real ear: Theme.islandEar
    property real r: 20
    property color fill: Theme.frame
    property bool shadow: true
    property bool outline: true             // the style's outline (off where something else draws it)
    property bool flipped: false            // standing on the bottom edge instead (the bar at the bottom)
    width: bodyW + 2 * e
    // the curves never grow past what the size allows
    readonly property real e: Math.max(0, Math.min(ear, height / 2))
    readonly property real rr: Math.max(0, Math.min(r, height - e, bodyW / 2))

    // the shadow, under the body: a RectangularShadow (a shader), so the island can grow into a
    // menu without its shape being rendered off-screen and blurred again on every frame (that
    // made menus stutter and open late on older laptops). It runs up past the screen's edge, so
    // only the sides and the round lower corners cast it.
    // (cut off at the edge it hangs from: a shape hanging under the bar mustn't shade the bar)
    Item {
        x: -80; y: 0
        width: s.width + 160; height: s.height + 80
        clip: true
        visible: s.shadow && Theme.shadowOn && s.height > 1
        transform: Scale { origin.y: s.height / 2; yScale: s.flipped ? -1 : 1 }
        RectangularShadow {
            x: 80 + s.e; y: -s.rr - 40
            width: s.bodyW; height: s.height + s.rr + 40
            radius: s.rr
            blur: Theme.shadowPx
            offset: Qt.vector2d(Theme.shadowX, Theme.shadowY)
            color: Theme.shadowColor
        }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.y: s.height / 2; yScale: s.flipped ? -1 : 1 }
        ShapePath {
            fillColor: s.fill
            // the style's outline (none by default)
            strokeColor: s.outline && Theme.outlineW > 0 ? Theme.outlineColor : "transparent"
            strokeWidth: s.outline ? Theme.outlineW : 0
            // along the screen edge, left to right
            startX: 0; startY: 0
            PathLine { x: s.width; y: 0 }
            // right ear: from the edge down into the body's side
            PathQuad { controlX: s.width - s.e; controlY: 0; x: s.width - s.e; y: s.e }
            PathLine { x: s.width - s.e; y: s.height - s.rr }
            PathArc { x: s.width - s.e - s.rr; y: s.height; radiusX: s.rr; radiusY: s.rr; direction: PathArc.Clockwise }
            PathLine { x: s.e + s.rr; y: s.height }
            PathArc { x: s.e; y: s.height - s.rr; radiusX: s.rr; radiusY: s.rr; direction: PathArc.Clockwise }
            PathLine { x: s.e; y: s.e }
            // left ear: back up to the edge
            PathQuad { controlX: s.e; controlY: 0; x: 0; y: 0 }
        }
    }

    // Liquid glass: the body is a pane of glass (square where it meets the screen edge); the ears
    // keep the faint fill
    LiquidPane {
        x: s.e; y: 0
        width: s.bodyW; height: s.height
        visible: Theme.liquid && s.fill.a > 0.001 && s.height > 4
        topLeft: s.flipped ? s.rr : 0; topRight: s.flipped ? s.rr : 0
        bottomRight: s.flipped ? 0 : s.rr; bottomLeft: s.flipped ? 0 : s.rr
    }
}
