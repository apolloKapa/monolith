import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The dock: a floating capsule of round app bubbles, pinned apps first, then other running
// apps. It shows on an empty workspace, or when the pointer touches the bottom edge.
PanelWindow {
    id: dock
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "monolith-dock"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    anchors { bottom: true; left: true; right: true }
    implicitHeight: 280
    color: "transparent"
    visible: enabled
    mask: Region { item: menu.visible ? fullArea : (shown ? capsule : hotZone) }
    Item { id: fullArea; anchors.fill: parent }

    readonly property var activeWs: Niri.workspacesOn(modelData.name).find(w => w.is_active)
    readonly property bool emptyWs: !!activeWs && !Niri.workspaceHasWindows(activeWs.id)
    property bool hovering: false
    readonly property bool enabled: Store.get("dock.enabled", true)
    // when it shows: always, on empty workspaces (and at the bottom edge), or only at the edge
    readonly property string showWhen: Store.get("dock.show", Store.get("dock.onEmpty", true) ? "empty" : "edge")
    readonly property bool shown: enabled && (showWhen === "always" || (emptyWs && showWhen === "empty") || hovering || leaveDelay.running || menu.visible)

    Item { id: hotZone; anchors.bottom: parent.bottom; width: parent.width; height: 3 }
    HoverHandler {
        onHoveredChanged: { dock.hovering = hovered; if (!hovered) leaveDelay.restart(); }
    }
    Timer { id: leaveDelay; interval: 400 }

    // the pinned apps: this shell's own list, starting from Monolith's dock apps
    readonly property var pinnedList: Store.get("dock.pinned", null) || Prefs.dockApps.map(a => ({ id: a.desktop_id, name: a.name, icon: a.icon }))
    function pin(item) { Store.set("dock.pinned", pinnedList.concat([{ id: item.id, name: item.name, icon: item.icon }])); }
    function unpin(item) { Store.set("dock.pinned", pinnedList.filter(p => p.id !== item.id)); }

    function iconFor(icon) {
        if (!icon) return Quickshell.iconPath("application-x-executable");
        return icon.startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable");
    }
    function windowsOf(appId) {
        const out = [];
        for (const k in Niri.windows) if ((Niri.windows[k].app_id || "").toLowerCase() === appId.toLowerCase()) out.push(Niri.windows[k]);
        return out;
    }
    readonly property var items: {
        const pinned = pinnedList.map(a => ({ id: a.id, name: a.name, icon: a.icon, pinned: true }));
        const known = pinned.map(p => p.id.toLowerCase());
        const extra = [];
        // open apps that aren't pinned (unless that's switched off)
        if (Store.get("dock.running", true) === false) return pinned;
        for (const k in Niri.windows) {
            const w = Niri.windows[k];
            const id = (w.app_id || "").toLowerCase();
            if (id === "" || known.indexOf(id) !== -1 || extra.find(e => e.id.toLowerCase() === id)) continue;
            const entry = DesktopEntries.byId(w.app_id);
            extra.push({ id: w.app_id, name: entry ? entry.name : w.app_id, icon: entry ? entry.icon : w.app_id, pinned: false });
        }
        return pinned.concat(extra);
    }

    Rectangle {
        id: capsule
        readonly property real cell: Number(Store.get("dock.size", 56))
        width: appsRow.width + 16
        height: cell + 16
        anchors.horizontalCenter: parent.horizontalCenter
        y: dock.shown ? parent.height - height - 12 : parent.height + 8
        Behavior on y { NumberAnimation { duration: dock.shown ? Theme.enterMs : Theme.exitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dock.shown ? Theme.enterCurve : Theme.exitCurve } }
        radius: Theme.corner(height, 8)
        color: Qt.alpha(Theme.card, Number(Store.get("dock.opacity", 1)))
        border.width: Math.max(1, Theme.outlineW)
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline

        Row {
            id: appsRow
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: dock.items
                Pressable {
                    id: app
                    required property var modelData
                    readonly property var wins: dock.windowsOf(modelData.id)
                    readonly property bool focused: wins.some(w => w.id === Niri.focusedWindowId)
                    width: capsule.cell
                    height: capsule.cell
                    radius: Theme.corner(height, 4)
                    color: focused ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
                    onRightClicked: {
                        const p = mapToItem(dock.contentItem, width / 2, 0);
                        menu.openFor(modelData, wins, p.x);
                    }
                    onClicked: {
                        if (wins.length > 0) {
                            // cycle through the app's windows
                            const i = wins.findIndex(w => w.id === Niri.focusedWindowId);
                            Niri.action(["focus-window", "--id", String(wins[(i + 1) % wins.length].id)]);
                        } else {
                            const e = DesktopEntries.byId(modelData.id);
                            if (e) e.execute();
                        }
                    }
                    Image {
                        anchors.centerIn: parent
                        width: Math.round(capsule.cell * 0.68); height: width
                        sourceSize: Qt.size(128, 128)
                        source: dock.iconFor(app.modelData.icon)
                        smooth: true; mipmap: true
                        scale: app.pressed ? 0.9 : (app.hovered ? (Store.get("dock.magnify", false) === true ? 1.3 : 1.08) : 1)
                        Behavior on scale { NumberAnimation { duration: 220; easing.type: Easing.OutCubic } }
                    }
                    // one dot per open window (up to three)
                    Row {
                        visible: Store.get("dock.dots", true) !== false
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 3
                        spacing: 3
                        Repeater {
                            model: Math.min(3, app.wins.length)
                            Rectangle { width: app.focused ? 10 : 5; height: 4; radius: 2; color: app.focused ? Theme.accent : Theme.subtext }
                        }
                    }
                }
            }
        }
    }

    // the right-click menu, above the app
    MouseArea { anchors.fill: parent; visible: menu.visible; onClicked: menu.visible = false }
    Rectangle {
        id: menu
        visible: false
        property var item: null
        property var wins: []
        function openFor(it, ws, cx) { item = it; wins = ws; x = Math.max(8, Math.min(dock.width - width - 8, cx - width / 2)); visible = true; }
        width: 230
        height: menuCol.implicitHeight + 12
        y: capsule.y - height - 10
        radius: Theme.corner(48, 8)
        color: Theme.card
        border.width: 1
        border.color: Theme.hairline
        Column {
            id: menuCol
            x: 6; y: 6
            width: parent.width - 12
            spacing: 2
            Label { leftPadding: 10; topPadding: 4; bottomPadding: 6; width: parent.width; text: menu.item ? menu.item.name : ""; strong: true }
            Repeater {
                model: menu.item ? [
                    ["open_in_new", "New window", "new"],
                    [menu.item.pinned ? "keep_off" : "keep", menu.item.pinned ? "Unpin" : "Pin to the dock", "pin"]
                ].concat(menu.wins.length > 0 ? [["close", menu.wins.length > 1 ? "Close " + menu.wins.length + " windows" : "Close window", "close"]] : []) : []
                Pressable {
                    required property var modelData
                    width: menuCol.width
                    height: 40
                    color: "transparent"
                    onClicked: {
                        const it = menu.item;
                        if (modelData[2] === "new") { const e = DesktopEntries.byId(it.id); if (e) e.execute(); }
                        else if (modelData[2] === "pin") { if (it.pinned) dock.unpin(it); else dock.pin(it); }
                        else if (modelData[2] === "close") for (const w of menu.wins) Niri.action(["close-window", "--id", String(w.id)]);
                        menu.visible = false;
                    }
                    Row {
                        x: 10
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 10
                        Icon { name: modelData[0]; size: 18; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: modelData[1]; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }
}
