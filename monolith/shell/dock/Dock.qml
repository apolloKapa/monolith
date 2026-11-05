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
    WlrLayershell.layer: Store.get("dock.onTop", false) === true ? WlrLayer.Overlay : WlrLayer.Top
    // which edge (Settings → Dock), and whether windows keep clear of it
    readonly property string side: Store.get("dock.position", "bottom")
    readonly property bool vertical: side === "left" || side === "right"
    readonly property bool exclusive: Store.get("dock.exclusive", false) === true
    exclusionMode: exclusive ? ExclusionMode.Normal : ExclusionMode.Ignore
    exclusiveZone: exclusive ? (vertical ? capsule.width : capsule.height) + dock.margin : 0
    anchors { bottom: side !== "top"; top: side !== "bottom"; left: side !== "right"; right: side !== "left" }
    implicitHeight: vertical ? 0 : 280
    implicitWidth: vertical ? 300 : 0
    readonly property real margin: Number(Store.get("dock.margin", 12))
    color: "transparent"
    visible: enabled
    mask: Region { item: menu.visible ? fullArea : (shown ? capsule : hotZone) }
    Item { id: fullArea; anchors.fill: parent }

    readonly property var activeWs: Niri.workspacesOn(modelData.name).find(w => w.is_active)
    readonly property bool emptyWs: !!activeWs && !Niri.workspaceHasWindows(activeWs.id)
    property bool hovering: false
    // on, and on this screen (Bar → Screens)
    readonly property bool enabled: Store.get("dock.enabled", true) && (Store.get("dock.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    // when it shows: always, on empty workspaces (and at the bottom edge), or only at the edge
    readonly property string showWhen: Store.get("dock.show", Store.get("dock.onEmpty", true) ? "empty" : "edge")
    readonly property bool shown: enabled && (showWhen === "always" || exclusive || (emptyWs && showWhen === "empty") || hovering || leaveDelay.running || menu.visible)

    // the strip along its edge that brings it back
    Item {
        id: hotZone
        x: dock.side === "right" ? parent.width - 3 : 0
        y: dock.side === "bottom" ? parent.height - 3 : 0
        width: dock.vertical ? 3 : parent.width
        height: dock.vertical ? parent.height : 3
    }
    HoverHandler {
        onHoveredChanged: { dock.hovering = hovered; if (!hovered) leaveDelay.restart(); }
    }
    Timer { id: leaveDelay; interval: Number(Store.get("dock.hideDelay", 400)) }

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
        // open apps that aren't pinned (unless that's switched off): all of them, or only those on
        // this workspace or this screen
        if (Store.get("dock.running", true) === false) return limit(pinned);
        const scope = Store.get("dock.runningScope", "all");
        const wsIds = Niri.workspacesOn(dock.modelData.name).map(w => w.id);
        for (const k in Niri.windows) {
            const w = Niri.windows[k];
            if (scope === "workspace" && (!dock.activeWs || w.workspace_id !== dock.activeWs.id)) continue;
            if (scope === "screen" && wsIds.indexOf(w.workspace_id) === -1) continue;
            const id = (w.app_id || "").toLowerCase();
            if (id === "" || known.indexOf(id) !== -1 || extra.find(e => e.id.toLowerCase() === id)) continue;
            const entry = DesktopEntries.byId(w.app_id);
            extra.push({ id: w.app_id, name: entry ? entry.name : w.app_id, icon: entry ? entry.icon : w.app_id, pinned: false });
        }
        return limit(pinned.concat(extra));
    }
    // at most this many (0: all)
    function limit(l) { const n = Number(Store.get("dock.maxApps", 0)); return n > 0 ? l.slice(0, n) : l; }

    Rectangle {
        id: capsule
        readonly property real cell: Number(Store.get("dock.size", 56))
        readonly property real opacityBg: Number(Store.get("dock.opacity", 1))
        width: appsRow.width + 16
        height: appsRow.height + 16
        // slides in from its edge
        x: dock.side === "left" ? (dock.shown ? dock.margin : -width - 8) : (dock.side === "right" ? (dock.shown ? parent.width - width - dock.margin : parent.width + 8) : Math.round((parent.width - width) / 2))
        y: dock.side === "bottom" ? (dock.shown ? parent.height - height - dock.margin : parent.height + 8) : (dock.vertical ? Math.round((parent.height - height) / 2) : (dock.shown ? dock.margin : -height - 8))
        Behavior on x { enabled: dock.vertical; NumberAnimation { duration: dock.shown ? Theme.enterMs : Theme.exitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dock.shown ? Theme.enterCurve : Theme.exitCurve } }
        Behavior on y { enabled: !dock.vertical; NumberAnimation { duration: dock.shown ? Theme.enterMs : Theme.exitMs; easing.type: Easing.BezierSpline; easing.bezierCurve: dock.shown ? Theme.enterCurve : Theme.exitCurve } }
        // its own roundness (−1: the theme's)
        radius: Number(Store.get("dock.radius", -1)) >= 0 ? Math.min(Number(Store.get("dock.radius", -1)), Math.min(width, height) / 2) : Theme.corner(Math.min(width, height), 8)
        color: Qt.alpha(Theme.card, opacityBg)
        // the outline: optional, and never on an invisible dock
        border.width: Store.get("dock.border", true) !== false && opacityBg > 0.02 ? Math.max(1, Theme.outlineW) : 0
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline

        Grid {
            id: appsRow
            anchors.centerIn: parent
            spacing: Number(Store.get("dock.spacing", 4))
            columns: dock.vertical ? 1 : Math.max(1, dock.items.length)
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
                        const p = mapToItem(dock.contentItem, width / 2, height / 2);
                        menu.openFor(modelData, wins, p.x, p.y);
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
        function openFor(it, ws, cx, cy) {
            item = it; wins = ws;
            if (dock.vertical) {
                x = dock.side === "left" ? capsule.x + capsule.width + 10 : capsule.x - width - 10;
                y = Math.max(8, Math.min(dock.height - height - 8, cy - height / 2));
            } else {
                x = Math.max(8, Math.min(dock.width - width - 8, cx - width / 2));
                y = dock.side === "top" ? capsule.y + capsule.height + 10 : capsule.y - height - 10;
            }
            visible = true;
        }
        width: 230
        height: menuCol.implicitHeight + 12
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

    // blur behind it (Theme → Effects), shaped like it
    BackgroundEffect.blurRegion: Theme.blur ? blurShape : null
    Region {
        id: blurShape
        item: dock.shown ? capsule : null
        radius: capsule.radius
    }
}
