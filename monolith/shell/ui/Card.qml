import QtQuick
import "../core"

// A tonal card inside the island: a title row (icon + name) and its content below.
Rectangle {
    id: card
    property string icon: ""
    property string title: ""
    default property alias content: slot.data
    property real pad: 14
    radius: Theme.corner(80, 10)
    color: Theme.container
    border.width: Theme.outlineW
    border.color: Theme.outlineColor
    Row {
        id: head
        visible: card.title !== ""
        x: card.pad; y: card.pad - 2
        spacing: 7
        Icon { name: card.icon; size: 17; color: Theme.accent; filled: true; anchors.verticalCenter: parent.verticalCenter }
        Label { text: card.title; strong: true; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
    }
    Item {
        id: slot
        x: card.pad
        y: head.visible ? head.y + head.height + 10 : card.pad
        width: card.width - 2 * card.pad
        height: card.height - y - card.pad
    }
}
