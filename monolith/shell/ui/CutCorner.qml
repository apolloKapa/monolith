import QtQuick
import "../core"

// The Cyberpunk style's cut corner on a layer: `layer.enabled: Theme.chamfer; layer.effect:
// CutCorner {}` on a card that holds a picture (a picture fills its card's corner, so the card's
// own cut doesn't show). The cut is the theme's size for the card (Theme.cut), as SmoothRect's.
ShaderEffect {
    property vector2d itemSize: Qt.vector2d(width, height)
    property real cut: Theme.cut(Math.min(width, height))
    fragmentShader: Qt.resolvedUrl("shaders/cutcorner.frag.qsb")
}
