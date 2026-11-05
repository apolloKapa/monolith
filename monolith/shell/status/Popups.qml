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
    readonly property bool here: Quickshell.screens.length > 0 && modelData === Quickshell.screens[0]

    WlrLayershell.namespace: "monolith-popups"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    // where they stack (Settings → Notifications): top-right, top-left, bottom-right, bottom-left
    readonly property string corner: Store.get("notifications.position", "top-right")
    anchors { top: corner.startsWith("top"); bottom: corner.startsWith("bottom"); right: corner.endsWith("right"); left: corner.endsWith("left") }
    margins { top: 46; bottom: 16; right: 12; left: 12 }
    // a fixed size (resizing a layer surface while it draws lost frames); only the cards take clicks
    implicitWidth: 390
    implicitHeight: 720
    mask: Region { item: stack }
    color: "transparent"
    visible: here && Notifs.popups.length > 0

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
                transform: Translate { x: (win.corner.endsWith("left") ? -40 : 40) * (1 - pc.enter) }

            }
        }
    }
}
