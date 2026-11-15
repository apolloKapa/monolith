import QtQuick
import "../core"

// A panel's material (Theme.material, a style's `material`: concrete, paper, steel), drawn by
// shaders/material.frag over the panel's flat fill and under what's in it: put it inside the
// panel, filling it, with the panel's corner radius (or per corner). It paints the panel's own
// colour (`color`), textured; each panel gets its own pattern from where it sits.
ShaderEffect {
    id: mp
    property real radius: 0
    property real topLeft: -1
    property real topRight: -1
    property real bottomRight: -1
    property real bottomLeft: -1
    property color color: Theme.frame
    visible: Theme.material !== "" && width > 2 && height > 2 && color.a > 0.01
    readonly property real r: Theme.square ? 0 : radius
    property vector2d itemSize: Qt.vector2d(width, height)
    property vector4d radii: Qt.vector4d(topLeft >= 0 ? topLeft : r, topRight >= 0 ? topRight : r,
                                          bottomRight >= 0 ? bottomRight : r, bottomLeft >= 0 ? bottomLeft : r)
    property color base: color
    property real kind: ({ concrete: 0, paper: 1, steel: 2 })[Theme.material] || 0
    // (a pattern of its own: from its size, so a panel keeps its look while it stays that size)
    property real seed: (Math.round(width) * 7 + Math.round(height) * 13) % 97
    property real strength: Theme.materialStrength
    fragmentShader: Qt.resolvedUrl("shaders/material.frag.qsb")
}
