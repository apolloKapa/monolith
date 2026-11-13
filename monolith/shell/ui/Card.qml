import QtQuick
import "../core"

// A tonal card inside the island: a title row (icon + name) and its content below.
SmoothRect {
    id: card
    property string icon: ""
    property string title: ""
    default property alias content: slot.data
    property real pad: 14
    property bool cascade: false      // on a menu: comes up with the others when the page opens
    Rise { on: card.cascade }
    HoverHandler { id: hov }
    radius: Theme.corner(80, 10)
    color: hov.hovered && card.cascade ? Theme.mix(Theme.container, Theme.containerHigh, 0.5) : Theme.container
    Behavior on color { ColorAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }
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
