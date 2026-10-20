import QtQuick
Item {
    id: s
    property real value: 0
    property bool dragging: ma.pressed
    signal moved(real v)
    implicitHeight: 28
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width; height: 6; color: "#333333" }
    Rectangle { anchors.verticalCenter: parent.verticalCenter; width: parent.width * Math.min(1, s.value); height: 6; color: "#ffffff" }
    Rectangle { x: parent.width * Math.min(1, s.value) - 6; anchors.verticalCenter: parent.verticalCenter; width: 12; height: 20; color: "#ffffff" }
    MouseArea {
        id: ma
        anchors.fill: parent
        function setv(mx) { s.moved(Math.max(0, Math.min(1, mx / width))) }
        onPressed: mouse => setv(mouse.x)
        onPositionChanged: mouse => { if (pressed) setv(mouse.x) }
    }
}
