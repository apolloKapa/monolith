import Quickshell
import QtQuick
Row {
    spacing: 8
    component HoldButton: Item {
        id: hb
        property string iconName: ""
        property var command: []
        property real fill: 0
        property bool fired: false
        implicitWidth: 28
        implicitHeight: 28
        function press() {
            down.stop()
            if (fill <= 0) fired = false
            up.duration = Math.max(1, Theme.holdTime * (1 - fill))
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
            border.width: 1
            border.color: (ma.containsMouse || hb.fill > 0) ? Theme.text : Theme.border
            clip: true
            Behavior on border.color { ColorAnimation { duration: Theme.animFast } }
            Image {
                id: ico
                anchors.centerIn: parent
                width: 16
                height: 16
                source: "image://icon/" + hb.iconName
                sourceSize: Qt.size(16, 16)
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: parent.height * hb.fill
                color: Theme.hoverBg
                clip: true
                Image {
                    x: (hb.width - 16) / 2
                    y: (hb.height - 16) / 2 - (hb.height - parent.height)
                    width: 16
                    height: 16
                    source: "image://icon/" + hb.iconName
                    sourceSize: Qt.size(16, 16)
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
    HoldButton { iconName: "system-reboot"; command: ["systemctl", "reboot"] }
    HoldButton { iconName: "system-shutdown"; command: ["systemctl", "poweroff"] }
}
