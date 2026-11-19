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
    // (or another line: something coming out of the Frame carries the frame's own outline on)
    property real lineW: Theme.outlineW
    property bool baseLine: true            // the outline runs along the edge it hangs from too
    property color lineColor: Theme.outlineColor
    property bool flipped: false            // standing on the bottom edge instead (the bar at the bottom)
    width: bodyW + 2 * e
    // the curves never grow past what the size allows
    // (no ears in the Cyberpunk style: it hangs straight down, square on the left, cut on the right)
    readonly property real e: Theme.chamfer ? 0 : Math.max(0, Math.min(ear, height / 2))
    readonly property real rr: Math.max(0, Math.min(r, height - e, bodyW / 2))
    // Cyberpunk (Theme.chamfer): the lower right corner is cut straight across (an arc of a huge
    // radius is a straight line) and the lower left one is square
    readonly property real arcR: Theme.chamfer ? 100000 : rr
    readonly property real lr: Theme.chamfer ? 0 : rr

    // the shadow, under the body: a RectangularShadow (a shader), so the island can grow into a
    // menu without its shape being rendered off-screen and blurred again on every frame (that
    // made menus stutter and open late on older laptops). It runs up past the screen's edge, so
    // only the sides and the round lower corners cast it.
    // (cut off at the edge it hangs from: a shape hanging under the bar mustn't shade the bar)
    Item {
        id: shadowBox
        x: -80; y: 0
        width: s.width + 160; height: s.height + 80
        clip: true
        visible: s.shadow && Theme.shadowOn && s.height > 1 && !Theme.chamfer
        transform: Scale { origin.y: s.height / 2; yScale: s.flipped ? -1 : 1 }
        // a see-through fill: the shadow only outside the body, like a card's (ui/CardShadow).
        // Under the body too it was a dark layer behind it, so a menu hanging from a floating
        // bar came out a darker shade than the bar it is one piece with, and hid half the blur
        layer.enabled: s.hollow && visible && Theme.rectShadows
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: hole
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
        }
        // (loaded by URL: an older Qt doesn't have it, see RectShadow.qml)
        Loader {
            x: 80 + s.e; y: -s.rr - 40
            width: s.bodyW; height: s.height + s.rr + 40
            active: Theme.rectShadows
            source: "RectShadow.qml"
            onLoaded: {
                item.radius = Qt.binding(() => s.rr);
                item.blur = Qt.binding(() => Theme.shadowPx);
                item.offset = Qt.binding(() => Qt.vector2d(Theme.shadowX, Theme.shadowY));
                item.color = Qt.binding(() => Theme.shadowColor);
            }
        }
    }
    // (false: the shadow stays under a see-through body too, which darkens it)
    property bool hollowShadow: true
    readonly property bool hollow: hollowShadow && s.fill.a > 0.01 && s.fill.a < 0.99
    // the body, where it sits in the shadow's box (the mask: no shadow there)
    Item {
        id: hole
        visible: false
        width: shadowBox.width; height: shadowBox.height
        layer.enabled: s.hollow && shadowBox.visible
        Rectangle { x: 80 + s.e; y: -s.rr - 4; width: s.bodyW; height: s.height + s.rr + 4; radius: s.rr }
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        transform: Scale { origin.y: s.height / 2; yScale: s.flipped ? -1 : 1 }
        // on a Qt without RectangularShadow: the shape casts its shadow the old way (blurred
        // off-screen, slower while it changes size)
        layer.enabled: s.shadow && !Theme.rectShadows
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
            strokeColor: s.outline && s.baseLine && s.lineW > 0 ? s.lineColor : "transparent"
            strokeWidth: s.outline && s.baseLine ? s.lineW : 0
            // along the screen edge, left to right
            startX: 0; startY: 0
            PathLine { x: s.width; y: 0 }
            // right ear: from the edge down into the body's side
            PathQuad { controlX: s.width - s.e; controlY: 0; x: s.width - s.e; y: s.e }
            PathLine { x: s.width - s.e; y: s.height - s.rr }
            PathArc { x: s.width - s.e - s.rr; y: s.height; radiusX: s.arcR; radiusY: s.arcR; direction: PathArc.Clockwise }
            PathLine { x: s.e + s.lr; y: s.height }
            PathArc { x: s.e; y: s.height - s.lr; radiusX: Math.max(0.01, s.lr); radiusY: Math.max(0.01, s.lr); direction: PathArc.Clockwise }
            PathLine { x: s.e; y: s.e }
            // left ear: back up to the edge
            PathQuad { controlX: s.e; controlY: 0; x: 0; y: 0 }
        }
        // (baseLine off: the same outline, but not along the edge it hangs from. Something growing
        // out of a bar is one piece with it: a line across where they join cut it off from the bar)
        ShapePath {
            fillColor: "transparent"
            strokeColor: s.outline && !s.baseLine && s.lineW > 0 ? s.lineColor : "transparent"
            strokeWidth: s.outline && !s.baseLine ? s.lineW : 0
            capStyle: ShapePath.FlatCap
            startX: s.width; startY: 0
            PathQuad { controlX: s.width - s.e; controlY: 0; x: s.width - s.e; y: s.e }
            PathLine { x: s.width - s.e; y: s.height - s.rr }
            PathArc { x: s.width - s.e - s.rr; y: s.height; radiusX: s.arcR; radiusY: s.arcR; direction: PathArc.Clockwise }
            PathLine { x: s.e + s.lr; y: s.height }
            PathArc { x: s.e; y: s.height - s.lr; radiusX: Math.max(0.01, s.lr); radiusY: Math.max(0.01, s.lr); direction: PathArc.Clockwise }
            PathLine { x: s.e; y: s.e }
            PathQuad { controlX: s.e; controlY: 0; x: 0; y: 0 }
        }
    }

    // a material: the body is made of it (square where it meets the screen edge), over the flat fill
    MaterialPane {
        x: s.e; y: 0
        width: s.bodyW; height: s.height
        color: s.fill
        visible: Theme.material !== "" && s.fill.a > 0.01 && s.height > 4
        topLeft: s.flipped ? s.rr : 0; topRight: s.flipped ? s.rr : 0
        bottomRight: s.flipped ? 0 : s.rr; bottomLeft: s.flipped ? 0 : s.rr
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
