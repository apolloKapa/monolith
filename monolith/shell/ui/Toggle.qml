import QtQuick
import "../core"

// Material's switch: a track with a thumb that grows and slides when on.
Item {
    id: t
    property bool checked: false
    signal toggled(bool on)
    implicitWidth: 52
    implicitHeight: 32
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: t.checked ? Theme.accent : Theme.control
        border.width: t.checked ? 0 : 2
        border.color: Theme.faint
        Behavior on color { ColorAnimation { duration: 200 } }
    }
    Rectangle {
        property real d: t.checked ? 24 : 16
        width: d; height: d
        radius: d / 2
        anchors.verticalCenter: parent.verticalCenter
        x: t.checked ? t.width - d - 4 : 8
        color: t.checked ? Theme.onAccent : Theme.subtext
        Behavior on x { NumberAnimation { duration: 260; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        Behavior on d { NumberAnimation { duration: 200 } }
        Behavior on color { ColorAnimation { duration: 200 } }
        Icon { anchors.centerIn: parent; visible: t.checked; name: "check"; size: 16; color: Theme.accent }
    }
    MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: { Sounds.play(t.checked ? "toggle-off" : "toggle-on"); t.toggled(!t.checked); } }
}
