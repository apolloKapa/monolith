import QtQuick
import QtQuick.Layouts
import "../core"

// A settings row: an icon bubble, the setting's name and what it does, and its control on
// the right (put the control inside the row).
Rectangle {
    id: row
    property string icon: ""
    property string title: ""
    property string desc: ""
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(64, texts.implicitHeight + 24)
    radius: Theme.corner(56, 2)
    color: Theme.containerHigh
    border.width: Theme.outlineW
    border.color: Theme.outlineColor
    Bubble { id: b; x: 12; anchors.verticalCenter: parent.verticalCenter; size: 38; icon: row.icon }
    Column {
        id: texts
        anchors.left: b.right; anchors.leftMargin: 12
        anchors.right: slot.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Label { width: parent.width; text: row.title; strong: true }
        Label { width: parent.width; text: row.desc; muted: true; font.pixelSize: Theme.sizeSmall; wrapMode: Text.Wrap; visible: text !== "" }
    }
    Item {
        id: slot
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
