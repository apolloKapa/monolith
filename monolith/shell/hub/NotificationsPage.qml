import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Notifications: Do Not Disturb, clear all, and every notification still around, newest first.
Page {
    id: page
    pageId: "notifications"
    implicitHeight: Math.min(560, head.height + 8 + Math.max(120, list.contentHeight))

    RowLayout {
        id: head
        width: parent.width
        height: 44
        Label { Layout.leftMargin: 6; text: Notifs.list.length === 0 ? "No notifications" : Notifs.list.length + (Notifs.list.length === 1 ? " notification" : " notifications"); strong: true }
        Item { Layout.fillWidth: true }
        Pressable {
            Layout.preferredHeight: 36
            Layout.preferredWidth: dndRow.implicitWidth + 24
            color: Notifs.dnd ? Theme.selected : Theme.containerHigh
            onClicked: Notifs.dnd = !Notifs.dnd
            Row {
                id: dndRow
                anchors.centerIn: parent
                spacing: 6
                Icon { name: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"; size: 18; filled: Notifs.dnd; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Do not disturb"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
            }
        }
        Pressable {
            Layout.preferredHeight: 36
            Layout.preferredWidth: clearRow.implicitWidth + 24
            visible: Notifs.list.length > 0
            onClicked: Notifs.clearAll()
            Row {
                id: clearRow
                anchors.centerIn: parent
                spacing: 6
                Icon { name: "clear_all"; size: 18; anchors.verticalCenter: parent.verticalCenter }
                Label { text: "Clear"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    Column {
        anchors.centerIn: list
        visible: Notifs.list.length === 0
        spacing: 6
        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: "notifications_paused"; size: 40; color: Theme.faint }
        Label { text: "You're all caught up"; muted: true }
    }

    ListView {
        id: list
        y: head.height + 8
        width: parent.width
        height: page.implicitHeight - y
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: Notifs.list
        add: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: 260 } }
        remove: Transition { NumberAnimation { property: "opacity"; to: 0; duration: 160 } }
        displaced: Transition { NumberAnimation { property: "y"; duration: Theme.moveMs; easing.type: Easing.OutCubic } }
        delegate: NotificationCard {
            required property var modelData
            notif: modelData
            width: list.width
            height: implicitHeight
            onClosed: modelData.dismiss()
        }
    }
}
