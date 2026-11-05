import QtQuick
import "../../"

// Orbit's leading icon: a glyph in a tonal bubble, filled with the accent when `active`
// (the same bubble the launcher puts in front of each app). Corners follow the border radius.
Rectangle {
    id: bubble
    property string glyph: ""
    property bool active: false
    property real size: Scaler.s(34)
    property real glyphSize: Math.round(size * 0.5)
    property color idleColor: ThemeBackend.surfaceContainerHighest
    property color activeColor: ThemeBackend.mauve
    property color idleGlyph: ThemeBackend.text
    property color activeGlyph: ThemeBackend.onPrimary

    implicitWidth: size
    implicitHeight: size
    width: size
    height: size
    radius: Math.min(size / 2, ThemeBackend.borderRadius + 2)
    color: active ? activeColor : idleColor
    Behavior on color { ColorAnimation { duration: 260 * ThemeBackend.animScale } }

    Text {
        anchors.centerIn: parent
        text: bubble.glyph
        font.family: ThemeBackend.iconFont
        font.pixelSize: bubble.glyphSize
        color: bubble.active ? bubble.activeGlyph : bubble.idleGlyph
        Behavior on color { ColorAnimation { duration: 260 * ThemeBackend.animScale } }
    }
}
