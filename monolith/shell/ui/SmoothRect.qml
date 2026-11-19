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
    // (cut: any rounding becomes a cut of the theme's size for this shape; none stays square)
    readonly property real r: Theme.chamfer ? (radius > 0.5 ? Math.min(half, Theme.cut(Math.min(width, height))) : 0) : Math.max(0, Math.min(radius, half))
    // cut corners (Theme.chamfer, the Cyberpunk style): a superellipse with exponent 1 is a
    // straight line across the corner; the shader cuts only the bottom-right one
    readonly property bool cut: Theme.chamfer && r >= 2
    // how far the curve reaches along each side (never past the middle: a capsule stays one)
    readonly property real extent: cut ? r : Math.min(half, r * (1 + 0.85 * smoothing))
    // the exponent that puts the curve's 45° point where a circle of radius r has it
    readonly property real expo: cut ? 1 : r <= 0 || extent <= r + 0.01 ? 2 : -Math.LN2 / Math.log(1 - 0.292893 * r / extent)
    readonly property bool curved: cut || (smoothing > 0.01 && r >= 4 && expo > 2.05)
    // for a blur region behind it (regions only have round corners): a circle this big sits
    // just inside the continuous corner, so no blur shows past the edge
    // (a cut one: square, with ui/CutBlur taking the cut corner out of the region)
    // (it was the corner's whole reach, `extent`: well inside, but a circle that big cuts the
    // corner short, 2 to 3 px at the diagonal, and the sharp backdrop showed there as a dark
    // crescent round every blurred corner. The blur's edge isn't smoothed, so it has to stay
    // under ours: a continuous corner crosses a circle of radius r at 45° and runs just inside
    // it towards the sides, where r + 1 still let single blurred pixels out past the edge;
    // r + 2 stays inside all the way round, under a pixel short at the diagonal. A plain round
    // corner needs only the one. Whole numbers: a region's radius is one)
    readonly property real blurRadius: cut || r <= 0.5 ? 0 : Math.min(half, Math.ceil(r) + (curved ? 2 : 1))
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
