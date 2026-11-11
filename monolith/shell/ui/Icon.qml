import QtQuick
import "../core"

// A Material Symbols icon by name ("wifi", "volume_up"). `filled` switches to the solid form.
Text {
    id: ic
    property string name: ""
    property real size: 20
    property bool filled: false
    property bool popOnChange: true
    text: name
    onNameChanged: if (popOnChange && shown && Theme.animOn) popAnim.restart()
    property bool shown: false
    Component.onCompleted: shown = true
    // a separate scale, so the icon's own `scale` (hover, press) keeps working
    transform: Scale { id: popS; origin.x: ic.width / 2; origin.y: ic.height / 2 }
    SequentialAnimation {
        id: popAnim
        NumberAnimation { target: popS; properties: "xScale,yScale"; to: 0.55; duration: Theme.ms(80); easing.type: Easing.InCubic }
        NumberAnimation { target: popS; properties: "xScale,yScale"; to: 1; duration: Theme.ms(260); easing.type: Easing.OutBack; easing.overshoot: 2 }
    }
    font.family: Theme.iconFont
    font.pixelSize: size
    font.variableAxes: ({ "FILL": filled ? 1 : 0, "wght": 400, "opsz": Math.max(20, Math.min(48, size)) })
    color: Theme.text
    horizontalAlignment: Text.AlignHCenter
    verticalAlignment: Text.AlignVCenter
    renderType: Text.NativeRendering
}
