import QtQuick
import QtQuick.Layouts
import "../core"

// How things stand, on top of a tab: a big icon, a line or two, and the switch.
Rectangle {
    id: hero
    property string icon: ""
    property string title: ""
    property string sub: ""
    property bool on: false          // the switch
    property bool lit: on            // tinted: something is connected
    property bool switchable: true
    signal toggled(bool on)
    Rise {}
    Layout.fillWidth: true
    Layout.preferredHeight: 84
    radius: Theme.corner(height, 6)
    color: lit ? Theme.selected : Theme.container
    border.width: Theme.outlineW
    border.color: Theme.outlineColor
    Behavior on color { ColorAnimation { duration: Theme.ms(260); easing.type: Easing.OutCubic } }
    Bubble { id: hb; x: 16; anchors.verticalCenter: parent.verticalCenter; size: 52; icon: hero.icon; on: hero.lit }
    Column {
        anchors.left: hb.right; anchors.leftMargin: 14
        anchors.right: sw.visible ? sw.left : parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        spacing: 3
        Label { width: parent.width; text: hero.title; strong: true; font.pixelSize: Theme.sizeTitle }
        Label { width: parent.width; text: hero.sub; muted: true; visible: text !== "" }
    }
    Toggle {
        id: sw
        visible: hero.switchable
        anchors.right: parent.right; anchors.rightMargin: 18
        anchors.verticalCenter: parent.verticalCenter
        checked: hero.on
        onToggled: v => hero.toggled(v)
    }
}
