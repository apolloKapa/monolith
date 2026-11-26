import QtQuick
import "../core"
import "../ui"

// An app's icon in the dock, in one of the dock's icon looks (Settings → Dock → Icons), like a
// phone's home screen can:
//   normal   the icon as the app ships it
//   tinted   every icon in shades of one colour (the tint), on a dark tile tinged with it
//   clear    frosted: pale, see-through icons on a sheet of clear glass
//   dark     the icon a little dimmer, on a dark tile
// The tiles are rounded squares, so icons of any shape line up as a set.
Item {
    id: di
    property url source
    property real size: 40
    property string look: "normal"
    property color tint: Theme.accent
    readonly property bool tiled: look !== "normal"
    width: size
    height: size

    Rectangle {
        visible: di.tiled
        anchors.fill: parent
        radius: (Theme.chamfer || Theme.square) ? 0 : width * 0.24
        antialiasing: true
        color: di.look === "clear" ? Qt.rgba(1, 1, 1, 0.12)
             : di.look === "tinted" ? Qt.tint("#0e0e11", Qt.alpha(di.tint, 0.16))
             : Qt.rgba(0.09, 0.09, 0.1, 0.92)
        border.width: 1
        border.color: di.look === "clear" ? Qt.rgba(1, 1, 1, 0.28) : Qt.alpha(di.look === "tinted" ? di.tint : "#ffffff", 0.14)
        // (a sheen across the top, as on glass)
        Rectangle {
            visible: di.look === "clear"
            anchors.fill: parent
            anchors.margins: 1
            radius: parent.radius - 1
            gradient: Gradient {
                GradientStop { position: 0; color: Qt.rgba(1, 1, 1, 0.16) }
                GradientStop { position: 0.5; color: Qt.rgba(1, 1, 1, 0) }
            }
        }
    }
    Image {
        id: art
        anchors.centerIn: parent
        width: Math.round(di.tiled ? di.size * 0.7 : di.size)
        height: width
        sourceSize: Qt.size(128, 128)
        source: di.source
        smooth: true
        mipmap: true
        visible: !di.tiled
    }
    // (recoloured by its own small shader: an effect that keeps an icon's brightness left white
    // glyphs white, where tinted should make them a pale shade of the tint)
    ShaderEffect {
        visible: di.tiled
        anchors.fill: art
        property var source: art
        property color tint: di.tint
        property real look: di.look === "tinted" ? 1 : (di.look === "clear" ? 2 : 3)
        fragmentShader: Qt.resolvedUrl("../ui/shaders/dockicon.frag.qsb")
    }
}
