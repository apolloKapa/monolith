import QtQuick
import QtQuick.Layouts
import "../core"

// A small title over a list, with one action at its end (scan again).
Item {
    id: sec
    property string text: ""
    property string action: ""
    property string hint: ""
    property bool spinning: false
    signal acted()
    Layout.fillWidth: true
    Layout.preferredHeight: 32
    Layout.topMargin: 4
    Label { x: 8; anchors.verticalCenter: parent.verticalCenter; text: sec.text; muted: true; strong: true; font.pixelSize: Theme.sizeSmall + 1 }
    Pressable {
        visible: sec.action !== ""
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        width: actRow.implicitWidth + 20
        height: 30
        color: "transparent"
        onClicked: sec.acted()
        Row {
            id: actRow
            anchors.centerIn: parent
            spacing: 6
            Label { text: sec.hint; muted: true; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
            Icon {
                name: sec.action; size: 18; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter
                RotationAnimator on rotation { running: sec.spinning; from: 0; to: 360; duration: 1000; loops: Animation.Infinite; onRunningChanged: if (!running) target.rotation = 0 }
            }
        }
    }
}
