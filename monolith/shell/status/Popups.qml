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
    margins {
        top: Theme.barEdge === "top" ? Theme.islandH + 16 : 16; bottom: Theme.barEdge === "bottom" ? Theme.islandH + 16 : 16
        right: 12 + (Theme.barSide === "right" ? Theme.sideRoom : 0); left: 12 + (Theme.barSide === "left" ? Theme.sideRoom : 0)
    }
    // a fixed size (resizing a layer surface while it draws lost frames); only the cards take clicks
    implicitWidth: 390
    implicitHeight: 720
    mask: Region { item: stack }
    color: "transparent"
    // only when they're set to pop up in a corner; by default they drop out of the island
    // (a bar down the side has no island to drop out of: they always come up here then)
    visible: mine.length > 0 && (Store.get("notifications.style", "island") === "corner" || Theme.barSide !== "")

    HoverHandler { id: hh }
    readonly property bool holding: hh.hovered && win.visible && win.mine.length > 0
    onHoldingChanged: Notifs.setHold("corner:" + modelData.name, holding)
    Component.onDestruction: Notifs.setHold("corner:" + modelData.name, false)

    // the cards, kept by notification: a new one is added where it goes and drops in on its own,
    // the others glide to their new places, a leaving one slides off. (The list used to be handed
    // straight to the Repeater: every notification that came or went rebuilt every card, and they
    // all dropped in again at once, into each other, when they came in quickly.)
    // At most `most` show; the rest wait in a "+N more" chip (the notification list).
    readonly property int most: 5
    readonly property var order: { const l = win.fromBottom ? win.mine.slice().reverse() : win.mine; return win.fromBottom ? l.slice(Math.max(0, l.length - most)) : l.slice(0, most); }
    readonly property int hidden: Math.max(0, win.mine.length - most)
    ListModel { id: cards }
    function sync() {
        const ids = order.map(n => n.id);
        for (let i = cards.count - 1; i >= 0; i--) if (ids.indexOf(cards.get(i).nid) < 0) cards.remove(i);
        for (let i = 0; i < ids.length; i++) {
            let at = -1;
            for (let j = i; j < cards.count; j++) if (cards.get(j).nid === ids[i]) { at = j; break; }
            if (at < 0) cards.insert(i, { nid: ids[i] });
            else if (at !== i) cards.move(at, i, 1);
        }
    }
    onOrderChanged: sync()
    Component.onCompleted: sync()
    function notifOf(id) { return win.mine.find(n => n.id === id) || null; }

    Column {
        id: stack
        width: parent.width
        anchors.bottom: win.fromBottom ? parent.bottom : undefined
        spacing: 8
        // the others glide to their new places when one comes or goes
        move: Transition { NumberAnimation { properties: "y"; duration: 260; easing.type: Easing.OutCubic } }
        // "+N more" where the stack ends at the bottom: above them all
        Pressable {
            visible: win.fromBottom && win.hidden > 0
            width: moreL.implicitWidth + 24; height: visible ? 26 : 0
            color: Theme.containerHigh
            onClicked: HubState.toggle("notifications", win.modelData.name)
            Label { id: moreL; anchors.centerIn: parent; text: "+" + win.hidden + " more"; font.pixelSize: Theme.sizeSmall; strong: true }
        }
        Repeater {
            model: cards
            Item {
                id: slot
                required property int nid
                readonly property var modelData: win.notifOf(nid)
                visible: modelData !== null
                width: stack.width
                height: modelData ? cardH : 0
                readonly property bool leaving: !!modelData && !!Notifs.leaving[modelData.id]
                // 0: up out of sight (down, at the bottom), 1: in place
                property real drop: 0
                Component.onCompleted: drop = 1
                Behavior on drop { NumberAnimation { duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.2 } }
                // going: it slides off sideways, towards the screen's edge, and the others close up
                property real away: leaving ? 1 : 0
                Behavior on away { NumberAnimation { duration: Notifs.leaveMs; easing.type: Easing.InCubic } }
                opacity: Math.min(1, drop * 1.6) * (1 - away)
                Loader {
                    active: slot.modelData !== null
                    width: slot.width
                    sourceComponent: NotificationCard {
                        id: pc
                        notif: slot.modelData
                        popup: true
                        width: slot.width
                        height: implicitHeight
                        y: (1 - slot.drop) * (win.fromBottom ? 1 : -1) * (height * 0.6 + 24)
                        x: slot.away * (win.corner.endsWith("left") ? -1 : 1) * (width * 0.5)
                        onClosed: Notifs.dismissPopup(slot.modelData, pc.flying)
                        onImplicitHeightChanged: slot.cardH = implicitHeight
                        Component.onCompleted: slot.cardH = implicitHeight
                        screenName: win.modelData.name
                        windowOffset: Qt.point(
                            win.anchors.right && !win.anchors.left ? win.screen.width - win.width - win.margins.right : (win.anchors.left && !win.anchors.right ? win.margins.left : (win.screen.width - win.width) / 2),
                            win.anchors.top && !win.anchors.bottom ? win.margins.top : (win.anchors.bottom && !win.anchors.top ? win.screen.height - win.height - win.margins.bottom : (win.screen.height - win.height) / 2))
                    }
                }
                property real cardH: 0
            }
        }
        // "+N more" under them at the top
        Pressable {
            visible: !win.fromBottom && win.hidden > 0
            width: moreT.implicitWidth + 24; height: visible ? 26 : 0
            color: Theme.containerHigh
            onClicked: HubState.toggle("notifications", win.modelData.name)
            Label { id: moreT; anchors.centerIn: parent; text: "+" + win.hidden + " more"; font.pixelSize: Theme.sizeSmall; strong: true }
        }
    }
}
