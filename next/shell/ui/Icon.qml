import QtQuick
import "../core"

// A Material Symbols icon by name ("wifi", "volume_up"). `filled` switches to the solid form.
Text {
    property string name: ""
    property real size: 20
    property bool filled: false
    text: name
    font.family: Theme.iconFont
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400, "opsz": Math.max(20, Math.min(48, size)) })
    color: Theme.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
