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
    onOnChanged: pop.restart()
    SequentialAnimation {
        id: pop
        NumberAnimation { target: b; property: "scale"; to: 1.14; duration: Theme.ms(110); easing.type: Easing.OutCubic }
        NumberAnimation { target: b; property: "scale"; to: 1; duration: Theme.ms(260); easing.type: Easing.OutBack }
    }
    Icon {
        anchors.centerIn: parent
        name: b.icon
        size: Math.round(b.size * 0.56)
        filled: b.on
        color: b.on ? Theme.onAccent : Theme.text
        Behavior on color { ColorAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
    }
}
