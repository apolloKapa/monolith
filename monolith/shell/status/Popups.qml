import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// New notifications, stacked in a corner (or an edge's middle). Each drops down from the top
// (rises from the bottom when they stack at the bottom), waits its timeout (critical ones
// stay) and slides off towards the screen's edge; swipe one sideways to dismiss it; hovering holds them. A popup stays
// on the screen it came up on.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    readonly property string first: Quickshell.screens.length ? Quickshell.screens[0].name : ""
    readonly property var mine: Notifs.popupsOn(modelData.name, first)

    WlrLayershell.namespace: "monolith-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    // where they stack (Settings → Notifications): a corner (top-right, …), or the middle of an
    // edge (top, bottom, left, right)
    readonly property string corner: Store.get("notifications.position", "top-right")
    readonly property bool fromBottom: corner.startsWith("bottom")
    anchors { top: corner.startsWith("top"); bottom: corner.startsWith("bottom"); right: corner.endsWith("right"); left: corner.endsWith("left") }
    margins { top: Theme.barBottom ? 16 : Theme.islandH + 16; bottom: Theme.barBottom ? Theme.islandH + 16 : 16; right: 12; left: 12 }
    // a fixed size (resizing a layer surface while it draws lost frames); only the cards take clicks
    implicitWidth: 390
    implicitHeight: 720
    mask: Region { item: stack }
    color: "transparent"
    // only when they're set to pop up in a corner; by default they drop out of the island
    visible: mine.length > 0 && Store.get("notifications.style", "island") === "corner"

    HoverHandler { onHoveredChanged: Notifs.hold = hovered }

    Column {
        id: stack
        width: parent.width
        anchors.bottom: win.fromBottom ? parent.bottom : undefined
        spacing: 8
        // the others glide to their new places when one comes or goes
        move: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }
        Repeater {
            // newest nearest the edge they come from
            model: win.fromBottom ? win.mine.slice().reverse() : win.mine
            Item {
                id: slot
                required property var modelData
                width: stack.width
                height: pc.implicitHeight
                readonly property bool leaving: !!Notifs.leaving[modelData.id]
                // 0: up out of sight (down, at the bottom), 1: in place
                property real drop: 0
                Component.onCompleted: drop = 1
                Behavior on drop { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                // going: it slides off sideways, towards the screen's edge, and the others close up
                property real away: leaving ? 1 : 0
                Behavior on away { NumberAnimation { duration: Notifs.leaveMs; easing.type: Easing.InCubic } }
                opacity: Math.min(1, drop * 1.6) * (1 - away)
                NotificationCard {
                    id: pc
                    notif: slot.modelData
                    popup: true
                    width: slot.width
                    height: implicitHeight
                    y: (1 - slot.drop) * (win.fromBottom ? 1 : -1) * (height * 0.6 + 24)
                    x: slot.away * (win.corner.endsWith("left") ? -1 : 1) * (width * 0.5)
                    onClosed: Notifs.dismissPopup(slot.modelData, pc.flying)
                    screenName: win.modelData.name
                    windowOffset: Qt.point(
                        win.anchors.right && !win.anchors.left ? win.screen.width - win.width - win.margins.right : (win.anchors.left && !win.anchors.right ? win.margins.left : (win.screen.width - win.width) / 2),
                        win.anchors.top && !win.anchors.bottom ? win.margins.top : (win.anchors.bottom && !win.anchors.top ? win.screen.height - win.height - win.margins.bottom : (win.screen.height - win.height) / 2))
                }
            }
        }
    }
}
