import QtQuick
import QtQuick.Layouts
import "../core"
import "../ui"

// Notifications: Do Not Disturb, clear all, and every notification still around, newest first.
Page {
    id: page
    pageId: "notifications"
    implicitHeight: Math.min(560, head.height + 8 + Math.max(200, list.contentHeight))

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

    Empty {
        anchors.centerIn: list
        width: list.width
        visible: Notifs.list.length === 0
        icon: Notifs.dnd ? "do_not_disturb_on" : "notifications_paused"
        title: "You're all caught up"
        sub: Notifs.dnd ? "Do not disturb is on: new ones arrive quietly." : "New notifications wait here until you clear them."
    }

    ListView {
        SmoothWheel {}
        id: list
        y: head.height + 8
        width: parent.width
        height: page.implicitHeight - y
        clip: true
        spacing: 8
        boundsBehavior: Flickable.StopAtBounds
        model: Notifs.list
        // new ones fade in with a little zoom, closed ones fade out the same way
        add: Transition { ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.popInMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: Theme.popScale; to: 1; duration: Theme.popInMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve } } }
        remove: Transition { ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Theme.popOutMs; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; to: Theme.popScale; duration: Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.exitCurve } } }
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
