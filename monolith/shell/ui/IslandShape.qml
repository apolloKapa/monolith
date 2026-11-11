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

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.y: s.height / 2; yScale: s.flipped ? -1 : 1 }
        // only the shape goes through the shadow effect: what sits in the island (the bar, a
        // menu, a notification) is drawn directly, so it stays sharp
        layer.enabled: s.shadow
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: Theme.shadowBlur
            shadowColor: Theme.shadowColor
            shadowVerticalOffset: Theme.shadowY
            shadowHorizontalOffset: Theme.shadowX
        }
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
