import QtQuick
import "../core"

// A round leading icon: tonal, or filled with the accent when `on`.
Rectangle {
    id: b
    property string icon: ""
    property bool on: false
    property real size: 36
    width: size
    height: size
    radius: Theme.corner(size, 4)
    color: on ? Theme.accent : Theme.control
    Behavior on color { ColorAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
    Icon {
        anchors.centerIn: parent
        name: b.icon
        size: Math.round(b.size * 0.56)
        filled: b.on
        color: b.on ? Theme.onAccent : Theme.text
        Behavior on color { ColorAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
    }
}
