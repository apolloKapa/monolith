import QtQuick

// A gradient over a layer (`layer.effect: GradientTint {}`), multiplied in: what's white takes
// the gradient's colours, what's black stays black. `dir`: the way it goes, as a vector (y down).
ShaderEffect {
    property color from: "white"
    property color to: "white"
    property vector2d dir: Qt.vector2d(0, 1)
    fragmentShader: Qt.resolvedUrl("shaders/gradtint.frag.qsb")
}
