import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The notifications dropdown: a click on the bar's bell drops the list out right under it
// (Do not disturb, clear all, every notification, newest first). A click anywhere else, the
// bell again or Esc puts it away.
PanelWindow {
    id: dd
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.dropScreen === modelData.name && HubState.dropKind === "notifications" && !HubState.open

    visible: shown || card.opacity > 0.01
    onVisibleChanged: if (visible) Qt.callLater(HubState.raisedOverlay)
    WlrLayershell.namespace: "monolith-notifications"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // open, the whole screen takes the mouse: a click off the card closes it
    mask: Region { item: dd.shown ? full : null }
    Item { id: full; anchors.fill: parent }

    MouseArea { anchors.fill: parent; onClicked: HubState.closeDrop() }
    Item {
        id: keys
        focus: true
        Keys.onEscapePressed: HubState.closeDrop()
    }
    onShownChanged: if (shown) keys.forceActiveFocus()

    Rectangle {
        id: card
        width: 420
        readonly property real listH: Notifs.list.length === 0 ? 170 : Math.min(list.contentHeight, 520)
        height: head.height + 8 + listH + 24
        Behavior on height { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.OutCubic } }
        readonly property point at: Theme.dropPos(HubState.dropX, HubState.dropY, width, height, dd.width, dd.height)
        x: at.x
        y: at.y
        radius: Theme.corner(80, 14)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        // drops down from the bar with a little zoom, and goes back up the same way
        opacity: dd.shown ? 1 : 0
        scale: dd.shown ? 1 : Theme.popScale
        transformOrigin: Theme.dropOrigin
        Behavior on opacity { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.OutCubic } }
        Behavior on scale { NumberAnimation { duration: dd.shown ? Theme.popInMs : Theme.popOutMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dd.shown ? Theme.enterCurve : Theme.exitCurve } }
        CardShadow {}
        MouseArea { anchors.fill: parent }

        RowLayout {
            id: head
            x: 12; y: 12
            width: card.width - 24
            height: 40
            Label { Layout.leftMargin: 4; text: Notifs.list.length === 0 ? "Notifications" : Notifs.list.length + (Notifs.list.length === 1 ? " notification" : " notifications"); strong: true }
            Item { Layout.fillWidth: true }
            Pressable {
                Layout.preferredHeight: 34
                Layout.preferredWidth: 34
                color: Notifs.dnd ? Theme.selected : Theme.containerHigh
                onClicked: Notifs.dnd = !Notifs.dnd
                Icon { anchors.centerIn: parent; name: Notifs.dnd ? "do_not_disturb_on" : "do_not_disturb_off"; size: 18; filled: Notifs.dnd }
            }
            Pressable {
                Layout.preferredHeight: 34
                Layout.preferredWidth: clearRow.implicitWidth + 22
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
            x: 12; y: list.y
            width: list.width; height: card.listH
            visible: Notifs.list.length === 0
            icon: Notifs.dnd ? "do_not_disturb_on" : "notifications_paused"
            title: "You're all caught up"
            sub: Notifs.dnd ? "Do not disturb is on." : "New notifications wait here."
        }

        ListView {
            SmoothWheel {}
            id: list
            x: 12; y: head.y + head.height + 8
            width: card.width - 24
            height: card.listH
            clip: true
            spacing: 8
            boundsBehavior: Flickable.StopAtBounds
            model: Notifs.list
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
                screenName: dd.modelData.name
                onClosed: modelData.dismiss()
            }
        }
    }
}
