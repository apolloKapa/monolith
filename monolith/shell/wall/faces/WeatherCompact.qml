import QtQuick
import "../../core"
import "../../ui"

// Weather, compact: on glass, the condition's icon (in the condition's colour) and the
// temperature. Wide, they sit side by side; otherwise one above the other.
FaceBase {
    id: face
    WeatherTone { id: sky }
    readonly property bool sideBySide: width > height * 1.15
    readonly property real pad: Math.max(6, Math.min(16, Math.min(width, height) * 0.08))
    // each half's box: half the room one way, all of it the other
    readonly property real halfW: sideBySide ? (width - 2 * pad) / 2 : width - 2 * pad
    readonly property real halfH: sideBySide ? height - 2 * pad : (height - 2 * pad) / 2
    readonly property real halfSide: Math.min(halfW, halfH)
    Glass { anchors.fill: parent; ctx: face.ctx; radius: Theme.corner(80, 14) }
    component Half: Item { width: face.halfW; height: face.halfH }
    Grid {
        anchors.centerIn: parent
        columns: face.sideBySide ? 2 : 1
        spacing: face.pad / 2
        Half { Icon { anchors.centerIn: parent; name: sky.icon; filled: true; color: sky.color; size: face.halfSide * 0.7 } }
        Half {
            Text {
                anchors.centerIn: parent
                renderType: Text.CurveRendering
                text: sky.temp
                color: Theme.text
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: face.halfSide / 2
            }
        }
    }
}
