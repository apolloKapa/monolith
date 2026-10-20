import Quickshell
import QtQuick

// hold to run: the box fills up like a bottle, when it is full it runs the command.
// Let go early and it drains again. A plain click does nothing.
Item {
    id: hb
    property string iconName: ""
    property var command: []
    property int holdMs: 1000
    property int boxSize: 56
    property int iconSize: 32
    property color edge: "#555555"
    property color ink: "#ffffff"
    property color water: "#ffffff"
    property real fill: 0
    property bool fired: false

    implicitWidth: boxSize
    implicitHeight: boxSize

    function press() {
        down.stop()
        if (fill <= 0) fired = false
        up.duration = Math.max(1, holdMs * (1 - fill))
        up.restart()
    }
    function release() {
        up.stop()
        down.duration = Math.max(1, 260 * fill)
        down.restart()
    }

    NumberAnimation {
        id: up
        target: hb
        property: "fill"
        to: 1
        easing.type: Easing.Linear
        onRunningChanged: {
            if (!running && hb.fill >= 0.999 && !hb.fired) {
                hb.fired = true
                Quickshell.execDetached(hb.command)
            }
        }
    }
    NumberAnimation { id: down; target: hb; property: "fill"; to: 0; easing.type: Easing.OutCubic }

    Rectangle {
        anchors.fill: parent
        color: "transparent"
        border.width: 2
        border.color: (ma.containsMouse || hb.fill > 0) ? hb.ink : hb.edge
        clip: true
        Behavior on border.color { ColorAnimation { duration: 120 } }

        Image {
            anchors.centerIn: parent
            width: hb.iconSize
            height: hb.iconSize
            source: "image://icon/" + hb.iconName
            sourceSize: Qt.size(hb.iconSize * 2, hb.iconSize * 2)
        }

        // the water
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: parent.height * hb.fill
            color: hb.water
            clip: true

            Image {
                x: (hb.width - hb.iconSize) / 2
                y: (hb.height - hb.iconSize) / 2 - (hb.height - parent.height)
                width: hb.iconSize
                height: hb.iconSize
                source: "image://icon/" + hb.iconName
                sourceSize: Qt.size(hb.iconSize * 2, hb.iconSize * 2)
            }
        }

        MouseArea {
            id: ma
            anchors.fill: parent
            hoverEnabled: true
            onPressed: hb.press()
            onReleased: hb.release()
            onCanceled: hb.release()
        }
    }
}
