import QtQuick
import "../core"

// A text button: tonal, or filled with the accent when `primary`.
Pressable {
    id: btn
    property string text: ""
    property string icon: ""
    property bool primary: false
    width: Math.max(96, row.implicitWidth + 32)
    height: 40
    color: primary ? Theme.accent : Theme.control
    ink: primary ? Theme.onAccent : Theme.text
    Row {
        id: row
        anchors.centerIn: parent
        spacing: 6
        Icon { visible: btn.icon !== ""; name: btn.icon; size: 18; color: btn.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        Label { text: btn.text; strong: true; color: btn.primary ? Theme.onAccent : Theme.text; anchors.verticalCenter: parent.verticalCenter }
    }
}
