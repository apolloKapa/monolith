import QtQuick
import "../core"

// A one-line text field; `accepted(text)` on Enter or when it loses focus.
Rectangle {
    id: fld
    property alias text: input.text
    property string placeholder: ""
    signal accepted(string v)
    width: 240
    height: 40
    radius: Theme.corner(height)
    color: Theme.container
    border.width: input.activeFocus ? 2 : 0
    border.color: Theme.accent
    TextInput {
        id: input
        anchors.fill: parent
        anchors.leftMargin: 14
        anchors.rightMargin: 14
        verticalAlignment: TextInput.AlignVCenter
        color: Theme.text
        selectionColor: Theme.selected
        font.family: Theme.fontFamily
        font.pixelSize: Theme.sizeSmall + 1
        clip: true
        onAccepted: fld.accepted(text)
        onActiveFocusChanged: if (!activeFocus) fld.accepted(text)
        Label { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: input.text === ""; text: fld.placeholder; muted: true; font.pixelSize: Theme.sizeSmall }
    }
}
