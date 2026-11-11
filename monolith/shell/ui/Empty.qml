import QtQuick
import QtQuick.Layouts
import "../core"

// Nothing to list: a picture, why, and (when there is one) the way out.
Item {
    id: em
    property string icon: ""
    property string title: ""
    property string sub: ""
    property string button: ""
    property string buttonIcon: ""
    property bool spinning: false
    signal acted()
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    implicitHeight: emCol.implicitHeight + 44
    implicitWidth: 380
    Column {
        id: emCol
        anchors.centerIn: parent
        width: Math.min(parent.width - 40, 380)
        spacing: 8
        Rectangle {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 68; height: 68; radius: 34
            color: Theme.container
            Icon {
                anchors.centerIn: parent; name: em.icon; size: 32; color: Theme.subtext
                RotationAnimator on rotation { running: em.spinning; from: 0; to: 360; duration: 1000; loops: Animation.Infinite }
            }
        }
        Item { width: 1; height: 2 }
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: em.title; strong: true; font.pixelSize: Theme.sizeTitle }
        Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: em.sub; muted: true; wrapMode: Text.WordWrap; elide: Text.ElideNone; visible: text !== "" }
        Item { width: 1; height: 4; visible: em.button !== "" }
        Button { visible: em.button !== ""; anchors.horizontalCenter: parent.horizontalCenter; text: em.button; icon: em.buttonIcon; primary: true; onClicked: em.acted() }
    }
}
