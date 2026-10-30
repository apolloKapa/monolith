import QtQuick
import "../../"

ShaderEffect {
    id: root

    property variant src
    property real topLeftRadius: 0
    property real topRightRadius: 0
    property real bottomLeftRadius: 0
    property real bottomRightRadius: 0
    property color tintColor: ThemeBackend.base
    property real tintAmount: 0
    property real bezel: Math.max(5, Math.min(26, Math.min(width, height) * 0.36))
    property real thickness: bezel * 1.15
    property real ior: 1.5
    property real dispersion: 0.11
    property real frost: 1.5
    property real rim: 0.45
    property real saturation: 1.25
    property rect sourceRect: Qt.rect(0, 0, 1, 1)
    property point cursorPos: Qt.point(0, 0)
    property real hover: 0
    property real clear: 0
    property real glassPad: 0
    property real shadowAmt: 0
    property real energy: 0
    property real nest: 0
    property real morph: 0
    property real motion: 0
    property vector2d filletDir: Qt.vector2d(0, 0)
    property real filletRadius: 0
    property real filletInset: 0
    property bool earsOnly: false
    property rect boxRect: Qt.rect(0, 0, 0, 0)
    property rect validRect: Qt.rect(0, 0, 1, 1)
    property real unpremul: 0
    // optional rounded hole, in item coordinates (the screen frame: glass all round the desktop)
    property rect holeRect: Qt.rect(0, 0, 0, 0)
    property real holeRadius: 0
    // optional notch kept out of the hole (a Frame bar narrower than its edge): its own corner
    // radius, and the fillets where it meets the frame
    property rect notchRect: Qt.rect(0, 0, 0, 0)
    property real notchRadius: 0
    property real notchFillet: 0

    property vector2d itemSize: Qt.vector2d(width, height)
    property vector4d radii: Qt.vector4d(topLeftRadius, topRightRadius, bottomRightRadius, bottomLeftRadius)
    property vector4d srcRect: Qt.vector4d(sourceRect.x, sourceRect.y, sourceRect.width, sourceRect.height)
    property vector2d cursor: Qt.vector2d(cursorPos.x, cursorPos.y)
    property vector4d fillet: Qt.vector4d(filletDir.x, filletDir.y, filletRadius, earsOnly ? 1 : 0)
    property vector4d sampleBounds: Qt.vector4d(validRect.x, validRect.y, validRect.x + validRect.width, validRect.y + validRect.height)
    property vector4d hole: holeRect.width > 0 ? Qt.vector4d(holeRect.x + holeRect.width * 0.5 - width * 0.5, holeRect.y + holeRect.height * 0.5 - height * 0.5, holeRect.width * 0.5, holeRect.height * 0.5) : Qt.vector4d(0, 0, 0, 0)
    property vector4d notch: notchRect.width > 0 ? Qt.vector4d(notchRect.x + notchRect.width * 0.5 - width * 0.5, notchRect.y + notchRect.height * 0.5 - height * 0.5, notchRect.width * 0.5, notchRect.height * 0.5) : Qt.vector4d(0, 0, 0, 0)
    property vector2d notchRadii: Qt.vector2d(notchRadius, notchFillet)
    property vector4d box:boxRect.width > 0 ? Qt.vector4d(boxRect.x + boxRect.width * 0.5 - width * 0.5, boxRect.y + boxRect.height * 0.5 - height * 0.5, boxRect.width * 0.5, boxRect.height * 0.5) : Qt.vector4d(0, 0, 0, 0)

    fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/effects/liquid_glass.frag.qsb"
}
