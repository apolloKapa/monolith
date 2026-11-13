import QtQuick
import "../core"

// A Rectangle with continuous corners: same color / radius / border as a Rectangle, but the
// corners are superellipse arcs that ease out of the sides (the "squircle" look) when
// Theme.cornerSmooth is on. The curve reaches further along each side than a circle of the
// same radius and is matched to cross the circle at 45°, so it reads as just as round.
// Small corners (under 4 px), capsules and Theme.cornerSmooth 0 draw a plain Rectangle (no
// shader, nothing extra to draw).
Item {
    id: sr
    property color color: "white"
    property real radius: 0
    readonly property SmoothBorder border: SmoothBorder {}
    property real smoothing: Theme.cornerSmooth
    readonly property real half: Math.max(0, Math.min(width, height) / 2)
    readonly property real r: Math.max(0, Math.min(radius, half))
    // how far the curve reaches along each side (never past the middle: a capsule stays one)
    readonly property real extent: Math.min(half, r * (1 + 0.85 * smoothing))
    // the exponent that puts the curve's 45° point where a circle of radius r has it
    readonly property real expo: r <= 0 || extent <= r + 0.01 ? 2 : -Math.LN2 / Math.log(1 - 0.292893 * r / extent)
    readonly property bool curved: smoothing > 0.01 && r >= 4 && expo > 2.05
    // for a blur region behind it (regions only have round corners): a circle this big sits
    // just inside the continuous corner, so no blur shows past the edge
    readonly property real blurRadius: curved ? extent : r
    readonly property bool painted: color.a > 0.002 || (border.width > 0 && border.color.a > 0.002)

    Rectangle {
        anchors.fill: parent
        visible: !sr.curved && sr.painted
        radius: sr.radius
        color: sr.color
        border.width: sr.border.width
        border.color: sr.border.color
    }
    ShaderEffect {
        anchors.fill: parent
        visible: sr.curved && sr.painted
        property vector2d itemSize: Qt.vector2d(width, height)
        property real extent: sr.extent
        property real expo: sr.expo
        property real borderW: sr.border.width
        property color fillColor: sr.color
        property color borderColor: sr.border.color
        fragmentShader: Qt.resolvedUrl("shaders/smooth.frag.qsb")
    }
}
