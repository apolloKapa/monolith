import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// New notifications, stacked under the status line's right end. Each slides in, waits its
// timeout (or 6 s; critical ones stay) and leaves; hovering holds it.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    // on the screen you're on
    readonly property bool here: Niri.focusedOutput !== "" ? Niri.focusedOutput === modelData.name : (Quickshell.screens.length > 0 && modelData === Quickshell.screens[0])

    WlrLayershell.namespace: "monolith-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    // where they stack (Settings → Notifications): a corner (top-right, …), or the middle of an
    // edge (top, bottom, left, right)
    readonly property string corner: Store.get("notifications.position", "top-right")
    anchors { top: corner.startsWith("top"); bottom: corner.startsWith("bottom"); right: corner.endsWith("right"); left: corner.endsWith("left") }
    margins { top: Theme.islandH + 16; bottom: 16; right: 12; left: 12 }
    // a fixed size (resizing a layer surface while it draws lost frames); only the cards take clicks
    implicitWidth: 390
    implicitHeight: 720
    mask: Region { item: stack }
    color: "transparent"
    // only when they're set to pop up in a corner; by default they drop out of the island
    visible: here && Notifs.popups.length > 0 && Store.get("notifications.style", "island") === "corner"

    HoverHandler { onHoveredChanged: Notifs.hold = hovered }

    Column {
        id: stack
        width: parent.width
        anchors.bottom: win.corner.startsWith("bottom") ? parent.bottom : undefined
        spacing: 8
        Repeater {
            model: Notifs.popups
            NotificationCard {
                id: pc
                required property var modelData
                notif: modelData
                popup: true
                width: stack.width
                height: implicitHeight
                onClosed: Notifs.dismissPopup(modelData)

                property real enter: 0
                Component.onCompleted: enter = 1
                Behavior on enter { NumberAnimation { duration: Theme.enterMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve } }
                opacity: enter
                // in from their side
                transform: Translate {
                    x: (win.corner.endsWith("left") ? -40 : (win.corner.endsWith("right") ? 40 : 0)) * (1 - pc.enter)
                    y: (win.corner === "top" ? -30 : (win.corner === "bottom" ? 30 : 0)) * (1 - pc.enter)
                }

            }
        }
    }
}
