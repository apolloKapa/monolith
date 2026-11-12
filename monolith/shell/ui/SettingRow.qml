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
    // the setting(s) this row changes: when one differs from its default, a ↺ button puts it back
    // (and the row is marked, so you can see at a glance what you've changed)
    property var keys: []
    property string key: ""
    property var def: undefined
    readonly property var allKeys: key !== "" ? [key].concat(keys) : keys
    readonly property bool changed: allKeys.some(k => Store.has(k) && (def === undefined || allKeys.length > 1 || JSON.stringify(Store.get(k, null)) !== JSON.stringify(def)))
    default property alias control: slot.data
    Layout.fillWidth: true
    implicitHeight: Math.max(64, texts.implicitHeight + 24)
    radius: Theme.corner(56, 2)
    color: hov.hovered ? Theme.mix(Theme.containerHigh, Theme.control, 0.55) : Theme.containerHigh
    Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
    border.width: Theme.outlineW
    border.color: Theme.outlineColor
    HoverHandler { id: hov }
    // found by the settings search: a soft accent glow that fades
    function glow() { glowAnim.restart(); }
    Rectangle {
        id: glowRect
        anchors.fill: parent
        radius: parent.radius
        color: "transparent"
        border.width: 2
        border.color: Theme.accent
        opacity: 0
        z: 5
        SequentialAnimation {
            id: glowAnim
            NumberAnimation { target: glowRect; property: "opacity"; to: 1; duration: 180 }
            PauseAnimation { duration: 900 }
            NumberAnimation { target: glowRect; property: "opacity"; to: 0; duration: 700; easing.type: Easing.InOutCubic }
        }
    }

    // rows come up one after another when a page opens (the lower, the later)
    property real enter: 0
    opacity: enter
    transform: Translate { y: (1 - row.enter) * 16 }
    SequentialAnimation {
        id: enterAnim
        PauseAnimation { id: enterWait }
        NumberAnimation { target: row; property: "enter"; to: 1; duration: Theme.ms(340); easing.type: Easing.OutCubic }
    }
    Timer { interval: 1; running: true; onTriggered: { enterWait.duration = Theme.ms(Math.min(320, Math.max(0, row.y) * 0.4)); enterAnim.start(); } }

    // the icon leans in when the pointer is on its row
    Bubble {
        id: b; x: 12; anchors.verticalCenter: parent.verticalCenter; size: 38; icon: row.icon
        scale: hov.hovered ? 1.1 : 1
        rotation: hov.hovered ? -6 : 0
        Behavior on scale { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } }
        Behavior on rotation { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } }
    }
    Column {
        id: texts
        anchors.left: b.right; anchors.leftMargin: 12
        anchors.right: revert.visible ? revert.left : slot.left; anchors.rightMargin: 12
        anchors.verticalCenter: parent.verticalCenter
        spacing: 2
        Row {
            spacing: 6
            Label { text: row.title; strong: true; width: Math.min(implicitWidth, texts.width - (row.changed ? 14 : 0)); elide: Text.ElideRight }
            // changed from the default
            Rectangle { visible: scale > 0.01; scale: row.changed ? 1 : 0; Behavior on scale { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack; easing.overshoot: 2.5 } } width: 7; height: 7; radius: 3.5; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
        }
        Label { width: parent.width; text: row.desc; muted: true; font.pixelSize: Theme.sizeSmall; wrapMode: Text.Wrap; visible: text !== "" }
    }
    // back to the default
    Pressable {
        id: revert
        visible: opacity > 0.01
        opacity: row.changed ? 1 : 0
        scale: row.changed ? 1 : 0.5
        Behavior on opacity { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } }
        anchors.right: slot.left; anchors.rightMargin: 8
        anchors.verticalCenter: parent.verticalCenter
        width: 32; height: 32
        color: hovered ? Theme.control : "transparent"
        onClicked: { for (const k of row.allKeys) Store.unset(k); }
        Icon { anchors.centerIn: parent; name: "settings_backup_restore"; size: 19; color: revert.hovered ? Theme.accent : Theme.subtext }
        Rectangle {
            visible: revert.hovered
            anchors.bottom: parent.top; anchors.bottomMargin: 6
            anchors.horizontalCenter: parent.horizontalCenter
            width: tip.implicitWidth + 16; height: 26; radius: 13
            color: Theme.frame
            border.width: 1; border.color: Theme.hairline
            Label { id: tip; anchors.centerIn: parent; text: "Back to default"; font.pixelSize: Theme.sizeSmall - 1 }
        }
    }
    Item {
        id: slot
        anchors.right: parent.right; anchors.rightMargin: 14
        anchors.verticalCenter: parent.verticalCenter
        width: childrenRect.width
        height: childrenRect.height
    }
}
