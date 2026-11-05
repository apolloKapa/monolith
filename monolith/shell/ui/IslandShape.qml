import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import "../core"

// The island's outline: a body `bodyW` × `height` hanging from the top edge, joined to the edge
// by a concave curve (`ear`) on each side, with round lower corners (`r`). The item is
// bodyW + 2·ear wide; the body sits between the ears. Filled, with a soft shadow under it.
Item {
    id: s
    property real bodyW: 400
    property real ear: Theme.islandEar
    property real r: 20
    property color fill: Theme.frame
    property bool shadow: true
    width: bodyW + 2 * e
    // the curves never grow past what the size allows
    readonly property real e: Math.max(0, Math.min(ear, height / 2))
    readonly property real rr: Math.max(0, Math.min(r, height - e, bodyW / 2))

    layer.enabled: shadow
    layer.effect: MultiEffect {
        shadowEnabled: true
        shadowBlur: Theme.shadowBlur
        shadowColor: Theme.shadowColor
        shadowVerticalOffset: Theme.shadowY
        shadowHorizontalOffset: 0
    }

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: s.fill
            strokeColor: "transparent"
            strokeWidth: 0
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
}
