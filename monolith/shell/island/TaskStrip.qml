import QtQuick
import Quickshell
import "../core"
import "../ui"
import "../dock"

// Desktop mode's taskbar (core/Desk.qml): the bar's module where the dock went. A start button
// (the launcher, with its rail of buttons), then your pinned apps and every other open one, each
// with a line along the screen's edge per open window. A click opens an app, brings its window
// back if it's minimised, minimises it if it's the one you're in, and goes through its windows if
// it has several; a right click opens its menu (status/TaskMenu.qml). The apps are the dock's own
// (Settings → Dock: pinned apps, the icons' look), so the two stay one list.
Grid {
    id: strip
    required property var host
    readonly property bool vertical: !!host && host.vertical
    columns: vertical ? 1 : 0
    rows: vertical ? 0 : 1
    spacing: 4
    horizontalItemAlignment: Grid.AlignHCenter
    verticalItemAlignment: Grid.AlignVCenter
    // (comes in as the dock sinks into the bar, and goes as it rises out)
    // two modules out of one: the start button ("start") and the apps ("taskbar"), each placed where
    // you like (Bar → Layout & modules, or a mini bar); Desktop mode puts them in the middle unless
    // you have
    property bool withStart: true
    property bool withApps: true
    // (in the bar of Desktop mode: in as the dock sinks into it, out as it rises. Anywhere else,
    // a mini bar or a bar without Desktop mode, simply there)
    opacity: !host || host.still || host.only || !Desk.on ? 1 : Math.max(0, Math.min(1, (Desk.fuse - 0.45) / 0.55))
    // its buttons: the bar's height, smaller when there are more apps than room (they'd run under
    // the bar's other modules)
    readonly property real fullCell: Math.max(28, Theme.islandH - 6)
    readonly property real wantCell: { const n = Math.max(1, (withApps ? apps.length : 0) + (withStart ? 1 : 0)); return Math.floor(Math.max(24, Math.min(fullCell, ((host ? host.taskRoom : 1e6) - spacing * (n - 1)) / n))); }
    // (smaller at once when there's no room, bigger only once there's clearly more: the room
    // changes by a pixel or two whenever a module's text does, the CPU's, the clock's, and the
    // icons resized with it)
    property real cell: wantCell
    onWantCellChanged: if (wantCell < cell || wantCell >= cell + 4 || wantCell === fullCell) cell = wantCell
    readonly property string edge: Theme.barEdge
    // (the start menu comes out of the start button: IslandBar.moduleBox)
    readonly property Item menuFrom: withStart ? start : null

    // the dock's pinned apps, then the open ones that aren't
    readonly property var pinned: Store.get("dock.pinned", null) || Prefs.dockApps.map(a => ({ id: a.desktop_id, name: a.name, icon: a.icon }))
    readonly property var apps: {
        const out = pinned.map(a => ({ id: a.id, name: a.name, icon: a.icon, pinned: true }));
        const known = out.map(a => String(a.id).toLowerCase());
        const ids = Object.keys(Niri.windows).sort((a, b) => String(a).localeCompare(String(b), undefined, { numeric: true }));
        for (const k of ids) {
            const w = Niri.windows[k];
            const id = String(w.app_id || "").toLowerCase();
            if (id === "" || known.indexOf(id) !== -1) continue;
            known.push(id);
            const e = DesktopEntries.byId(w.app_id);
            out.push({ id: w.app_id, name: e ? e.name : w.app_id, icon: e ? e.icon : w.app_id, pinned: false });
        }
        return out;
    }
    function windowsOf(appId) {
        const out = [];
        const id = String(appId).toLowerCase();
        for (const k in Niri.windows) if (String(Niri.windows[k].app_id || "").toLowerCase() === id) out.push(Niri.windows[k]);
        // the one used last first (Hyprland keeps that order; niri: as they are)
        return out.sort((a, b) => (a.focus_history !== undefined ? a.focus_history : 0) - (b.focus_history !== undefined ? b.focus_history : 0));
    }
    function iconFor(icon) {
        if (!icon) return Quickshell.iconPath("application-x-executable");
        return String(icon).startsWith("/") ? "file://" + icon : Quickshell.iconPath(icon, "application-x-executable");
    }
    readonly property string iconLook: { const v = String(Store.get("dock.iconStyle", "normal")); return ["tinted", "clear", "dark"].indexOf(v) !== -1 ? v : "normal"; }
    readonly property color iconTint: { const v = String(Store.get("dock.iconTint", "") || ""); return /^#[0-9a-fA-F]{6}$/.test(v) ? v : Theme.accent; }

    function activate(app) {
        const wins = windowsOf(app.id);
        if (wins.length === 0) {
            const e = DesktopEntries.byId(app.id) || DesktopEntries.byId(app.id + ".desktop");
            if (e) { Sounds.play("launch"); e.execute(); }
            return;
        }
        const i = wins.findIndex(w => w.id === Niri.focusedWindowId);
        if (i === -1) { Desk.focus(wins[0]); return; }
        // the one you're in: down it goes (only one), or on to the next
        if (wins.length === 1) Desk.minimize(wins[0]);
        else Desk.focus(wins[(i + 1) % wins.length]);
    }

    // the start button: the launcher (Desktop mode gives it its rail)
    Pressable {
        id: start
        visible: strip.withStart
        readonly property bool on: HubState.open && HubState.page === "search"
        width: strip.cell; height: strip.cell
        radius: Theme.corner(height, 4)
        color: on ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
        onPressedChanged: if (pressed) { const p = start.mapToItem(null, 0, 0); strip.host.pressedAt = { screen: strip.host.screenName, x: p.x, y: p.y, w: start.width, h: start.height, t: Date.now() }; }
        onClicked: strip.host.open("search")
        SmoothRect {
            smoothing: 0
            anchors.centerIn: parent
            width: Math.round(strip.cell * 0.66); height: width
            radius: Theme.corner(width, 5)
            color: start.on ? Theme.accent : Theme.accentContainer
            scale: start.pressed ? 0.88 : 1
            Behavior on scale { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
            Icon { anchors.centerIn: parent; name: "grid_view"; size: Math.round(strip.cell * 0.4); filled: true; color: start.on ? Theme.onAccent : Theme.onAccentContainer }
        }
    }

    Repeater {
        model: strip.withApps ? strip.apps : []
        Pressable {
            id: app
            required property var modelData
            readonly property var wins: strip.windowsOf(modelData.id)
            readonly property bool focused: wins.some(w => w.id === Niri.focusedWindowId)
            readonly property bool allMin: wins.length > 0 && wins.every(w => Desk.isMin(w))
            width: strip.cell; height: strip.cell
            radius: Theme.corner(height, 4)
            color: focused ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
            Behavior on color { ColorAnimation { duration: Theme.fastMs } }
            onClicked: strip.activate(modelData)
            onRightClicked: {
                const p = strip.host.edgePoint(app);
                HubState.toggleTask(modelData, strip.host.screenName, p.x, p.y);
            }
            DockIcon {
                anchors.centerIn: parent
                size: Math.round(strip.cell * (strip.iconLook === "normal" ? 0.62 : 0.74))
                source: strip.iconFor(app.modelData.icon)
                look: strip.iconLook
                tint: strip.iconTint
                opacity: app.allMin ? 0.75 : 1
                scale: app.pressed ? 0.86 : (app.hovered ? 1.06 : 1)
                Behavior on scale { NumberAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
            }
            // a line along the screen's edge while it has windows: long for the one you're in,
            // short for the rest, faint when they're all minimised
            Rectangle {
                visible: app.wins.length > 0
                property real along: app.focused ? strip.cell * 0.42 : strip.cell * 0.16
                Behavior on along { NumberAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }
                width: strip.vertical ? 3 : along
                height: strip.vertical ? along : 3
                radius: (Theme.chamfer || Theme.square) ? 0 : 1.5
                color: app.focused ? Theme.accent : (app.allMin ? Qt.alpha(Theme.subtext, 0.6) : Theme.subtext)
                x: strip.edge === "left" ? 1 : (strip.edge === "right" ? app.width - width - 1 : Math.round((app.width - width) / 2))
                y: strip.edge === "bottom" ? app.height - height - 1 : (strip.edge === "top" ? 1 : Math.round((app.height - height) / 2))
            }
        }
    }
}
