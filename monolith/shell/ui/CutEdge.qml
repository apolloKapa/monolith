import QtQuick
import QtQuick.Shapes
import "../core"

// An outline that follows the Cyberpunk cut (square corners, the bottom-right one cut across),
// for a card whose picture covers its own border (with CutCorner on the card). Only in that
// style: elsewhere the card's own border is used.
Shape {
    id: ce
    anchors.fill: parent
    z: 10
    property color color: Theme.outlineColor
    property real lineWidth: Math.max(1, Theme.outlineW)
    visible: Theme.chamfer && lineWidth > 0 && color.a > 0
    readonly property real c: Theme.cut(Math.min(width, height))
    readonly property real h: lineWidth / 2
    preferredRendererType: Shape.CurveRenderer
    ShapePath {
        fillColor: "transparent"
        strokeColor: ce.color
        strokeWidth: ce.lineWidth
        joinStyle: ShapePath.MiterJoin
        startX: ce.h; startY: ce.h
        PathLine { x: ce.width - ce.h; y: ce.h }
        PathLine { x: ce.width - ce.h; y: ce.height - ce.c }
        PathLine { x: ce.width - ce.c; y: ce.height - ce.h }
        PathLine { x: ce.h; y: ce.height - ce.h }
        PathLine { x: ce.h; y: ce.h }
    }
}
