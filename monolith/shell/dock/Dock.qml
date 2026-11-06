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
    implicitHeight: vertical ? 0 : (editing ? 620 : 280)
    implicitWidth: vertical ? (editing ? 620 : 300) : 0
    WlrLayershell.keyboardFocus: editing ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    // on the same edge as the bar it sits clear of it (an exclusive dock is already moved by it)
    readonly property bool barEdge: !exclusive && ((side === "bottom" && Theme.barBottom) || (side === "top" && !Theme.barBottom))
    readonly property real margin: Number(Store.get("dock.margin", 12)) + (barEdge ? Theme.islandH + Theme.barMargin : 0)
    color: "transparent"
    visible: enabled
    // shown: where the dock ends up (not where it is while sliding in: the pointer at the edge
    // would be outside that for a moment, the dock would think it had been left and hide again)
    // stretched to the edge, so moving from the edge to the dock never leaves it; hidden: the strip
    mask: Region {
        item: menu.visible || dock.editing ? fullArea : (dock.shown ? reach : hotZone)
        // the edge strip stays in while shown (resting on the edge away from the dock keeps it)
        Region { item: dock.shown && !menu.visible && !dock.editing ? hotZone : null }
    }
    Item { id: fullArea; anchors.fill: parent }

    readonly property var activeWs: Niri.workspacesOn(modelData.name).find(w => w.is_active)
    readonly property bool emptyWs: !!activeWs && !Niri.workspaceHasWindows(activeWs.id)
    property bool hovering: false
    // on, and on this screen (Bar → Screens)
    readonly property bool enabled: Store.get("dock.enabled", true) && (Store.get("dock.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    // when it shows: always, on empty workspaces (and at the bottom edge), or only at the edge
    readonly property string showWhen: Store.get("dock.show", Store.get("dock.onEmpty", true) ? "empty" : "edge")
    // the dock editor (hold an app or the dock for a moment): reorder, unpin, add apps
    property bool editing: false
    property int dragIndex: -1
    property point dragPos: Qt.point(0, 0)
    property string pickQuery: ""
    function movePinned(from, to) {
        if (from === to || from < 0) return;
        const l = pinnedList.slice();
        const it = l.splice(from, 1)[0];
        l.splice(Math.max(0, Math.min(to, l.length)), 0, it);
        Store.set("dock.pinned", l);
    }
    function indexAt(p) {
        const step = capsule.cell + appsRow.spacing;
        return Math.max(0, Math.min(pinnedList.length - 1, Math.floor((vertical ? p.y : p.x) / step)));
    }
    Connections { target: HubState; function onDockEditChanged() { if (HubState.dockEdit === dock.modelData.name) { dock.editing = true; HubState.dockEdit = ""; } } }
    onEditingChanged: { pickQuery = ""; picker.visible = false; if (editing) editKeys.forceActiveFocus(); }

    // dodge windows: up, unless a window is over (or touching) the dock's spot on this screen's
    // current workspace. Floating windows count by where they are; tiled ones fill the screen's
    // height, so any tiled window counts (niri doesn't say where on screen a tile sits).
    readonly property bool covered: {
        if (showWhen !== "dodge" || !activeWs) return false;
        const ws = activeWs.id;
        const touch = 4;
        for (const k in Niri.windows) {
            const w = Niri.windows[k];
            if (!w || w.workspace_id !== ws) continue;
            const L = w.layout;
            const pos = L ? L.tile_pos_in_workspace_view : null;
            if (!pos) { if (!w.is_floating) return true; continue; }
            const sz = L.tile_size || [0, 0];
            // the dock's spot in screen coordinates (its window sits against its edge)
            const ox = dock.side === "right" ? dock.screen.width - dock.width : 0;
            const oy = dock.side === "bottom" ? dock.screen.height - dock.height : 0;
            const rx = ox + reach.x, ry = oy + reach.y;
            if (pos[0] < rx + reach.width + touch && pos[0] + sz[0] > rx - touch
                    && pos[1] < ry + reach.height + touch && pos[1] + sz[1] > ry - touch)
                return true;
        }
        return false;
    }
    readonly property bool shown: enabled && (editing || showWhen === "always" || exclusive || (emptyWs && showWhen === "empty") || (showWhen === "dodge" && !covered) || hovering || leaveDelay.running || menu.visible)

    // the shown dock's place, from its edge to its far side
    Item {
        id: reach
        readonly property real cw: capsule.width
        readonly property real ch: capsule.height
        x: dock.side === "left" ? 0 : (dock.side === "right" ? parent.width - cw - dock.margin : Math.round((parent.width - cw) / 2))
        y: dock.side === "bottom" ? parent.height - ch - dock.margin : (dock.vertical ? Math.round((parent.height - ch) / 2) : 0)
        width: dock.vertical ? cw + dock.margin : cw
        height: dock.vertical ? ch : ch + dock.margin
    }
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
    readonly property var items: dock.editing ? pinnedList.map(a => ({ id: a.id, name: a.name, icon: a.icon, pinned: true })) : allItems
    readonly property var allItems: {
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

        MouseArea {
            anchors.fill: parent
            pressAndHoldInterval: 700
            onPressAndHold: dock.editing = true
        }
        PanelFx { anchors.fill: parent; radius: capsule.radius; visible: capsule.opacityBg > 0.02 && (Theme.fxGrain || Theme.fxEdge) }
        Grid {
            id: appsRow
            anchors.centerIn: parent
            spacing: Number(Store.get("dock.spacing", 4))
            columns: dock.vertical ? 1 : Math.max(1, dock.items.length + (dock.editing ? 2 : 0))
            Repeater {
                model: dock.items
                Pressable {
                    id: app
                    required property var modelData
                    required property int index
                    opacity: dock.dragIndex === index ? 0.3 : 1
                    // hold for a moment: the dock editor
                    Timer { id: hold; interval: 700; onTriggered: { app.held = true; dock.editing = true; } }
                    property bool held: false
                    onPressedChanged: { if (pressed && !dock.editing) { held = false; hold.restart(); } else hold.stop(); }
                    // editing: drag to reorder
                    MouseArea {
                        anchors.fill: parent
                        enabled: dock.editing
                        preventStealing: true
                        cursorShape: dock.dragIndex === app.index ? Qt.ClosedHandCursor : Qt.OpenHandCursor
                        property point start
                        property bool moved: false
                        onPressed: mouse => { start = Qt.point(mouse.x, mouse.y); moved = false; }
                        onPositionChanged: mouse => {
                            if (!pressed) return;
                            if (!moved && Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 6) { moved = true; dock.dragIndex = app.index; }
                            if (moved) dock.dragPos = mapToItem(appsRow, mouse.x, mouse.y);
                        }
                        // end the drag first, then reorder: saving rebuilds the dock (this tile too)
                        onReleased: {
                            const from = app.index, to = dock.indexAt(dock.dragPos), wasMoved = moved;
                            dock.dragIndex = -1;
                            moved = false;
                            if (wasMoved) Qt.callLater(() => dock.movePinned(from, to));
                        }
                        onCanceled: dock.dragIndex = -1
                    }
                    // editing: unpin
                    Rectangle {
                        visible: dock.editing
                        z: 5
                        x: parent.width - 18; y: -4
                        width: 22; height: 22; radius: 11
                        color: Theme.danger
                        Icon { anchors.centerIn: parent; name: "close"; size: 15; color: Theme.card }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: dock.unpin(app.modelData) }
                    }
                    readonly property var wins: dock.windowsOf(modelData.id)
                    readonly property bool focused: wins.some(w => w.id === Niri.focusedWindowId)
                    width: capsule.cell
                    height: capsule.cell
                    radius: Theme.corner(height, 4)
                    color: focused ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
                    onRightClicked: {
                        if (dock.editing) return;
                        const p = mapToItem(dock.contentItem, width / 2, height / 2);
                        menu.openFor(modelData, wins, p.x, p.y);
                    }
                    onClicked: {
                        if (dock.editing || held) { held = false; return; }
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
            // editing: add apps, and done
            Pressable {
                visible: dock.editing
                width: capsule.cell; height: capsule.cell
                color: picker.visible ? Theme.accentContainer : Theme.containerHigh
                onClicked: picker.visible = !picker.visible
                Icon { anchors.centerIn: parent; name: "add"; size: 26; color: Theme.accent }
            }
            Pressable {
                visible: dock.editing
                width: capsule.cell; height: capsule.cell
                color: Theme.accent; ink: Theme.onAccent
                onClicked: dock.editing = false
                Icon { anchors.centerIn: parent; name: "check"; size: 26; color: Theme.onAccent }
            }
        }
    }

    // holding the dock's background also opens the editor; while editing, a click outside ends it
    MouseArea { anchors.fill: parent; visible: dock.editing && !picker.visible; onClicked: dock.editing = false }
    Item {
        id: editKeys
        focus: dock.editing
        Keys.onEscapePressed: { if (picker.visible) picker.visible = false; else dock.editing = false; }
    }

    // the app picker: every app that isn't pinned, with a search
    Rectangle {
        id: picker
        visible: false
        z: 20
        width: dock.vertical ? Math.min(dock.width - capsule.width - 40, 520) : Math.min(dock.width - 40, 640)
        height: dock.vertical ? Math.min(dock.height - 80, 520) : Math.min(dock.height - capsule.height - 40, 480)
        x: dock.side === "left" ? capsule.x + capsule.width + 12 : (dock.side === "right" ? capsule.x - width - 12 : Math.round((dock.width - width) / 2))
        y: dock.vertical ? Math.round((dock.height - height) / 2) : (dock.side === "top" ? capsule.y + capsule.height + 12 : capsule.y - height - 12)
        radius: Theme.corner(80, 12)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        MouseArea { anchors.fill: parent }
        readonly property var apps: DesktopEntries.applications.values
            .filter(a => !a.noDisplay && !dock.pinnedList.some(p => p.id === a.id || p.id + ".desktop" === a.id))
            .filter(a => dock.pickQuery === "" || a.name.toLowerCase().includes(dock.pickQuery.toLowerCase()))
            .sort((a, b) => a.name.localeCompare(b.name))
        Label { x: 16; y: 14; text: "Add to the dock"; strong: true; font.pixelSize: Theme.sizeTitle }
        Field {
            id: pickField
            x: 16; y: 44
            width: parent.width - 32
            placeholder: "Search apps"
            onAccepted: v => dock.pickQuery = v
            onTextChanged: dock.pickQuery = text
        }
        GridView {
            x: 12; y: 96
            width: parent.width - 24
            height: parent.height - y - 12
            clip: true
            cellWidth: width / 5
            cellHeight: 88
            // only while it's open (a hidden grid still builds every icon in view, on every screen)
            model: picker.visible ? picker.apps : []
            SmoothWheel {}
            delegate: Pressable {
                required property var modelData
                width: GridView.view.cellWidth - 4
                height: 84
                color: hovered ? Theme.containerHigh : "transparent"
                onClicked: dock.pin({ id: modelData.id, name: modelData.name, icon: modelData.icon })
                Column {
                    anchors.centerIn: parent
                    width: parent.width - 8
                    spacing: 6
                    Image { anchors.horizontalCenter: parent.horizontalCenter; width: 38; height: 38; sourceSize: Qt.size(76, 76); source: dock.iconFor(parent.parent.modelData.icon); asynchronous: true }
                    Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: parent.parent.modelData.name; font.pixelSize: Theme.sizeSmall }
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
