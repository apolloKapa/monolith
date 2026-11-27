import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// An app's menu on Desktop mode's taskbar (a right click on it, island/TaskStrip.qml): a card
// out of the taskbar like the tray's. Its windows (when it has several: a click goes to one),
// a new window, pin or unpin, minimise or bring back, maximise, close.
PanelWindow {
    id: dd
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.dropScreen === modelData.name && HubState.dropKind === "task" && !HubState.open && !!HubState.taskApp

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-taskmenu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: dd.shown ? full : null }
    // blur behind the card (Theme → Effects), once it's fully out: it was see-through over windows
    BackgroundEffect.blurRegion: Theme.blur && dd.shown && card.opacity > 0.99 ? blurShape : null
    Region { id: blurShape; item: card; radius: card.radius }
    Item { id: full; anchors.fill: parent }
    MouseArea { anchors.fill: parent; onClicked: HubState.closeDrop() }
    Item { id: keys; focus: true; Keys.onEscapePressed: HubState.closeDrop() }
    onShownChanged: if (shown) keys.forceActiveFocus()

    // (kept while it fades out: the app is still there to draw)
    property var app: null
    Connections { target: HubState; function onTaskAppChanged() { if (HubState.taskApp) dd.app = HubState.taskApp; } }
    Component.onCompleted: app = HubState.taskApp
    readonly property var wins: {
        if (!app) return [];
        const out = [];
        for (const k in Niri.windows) if (Desk.isAppWindow(app.id, Niri.windows[k])) out.push(Niri.windows[k]);
        return out;
    }
    readonly property bool allMin: wins.length > 0 && wins.every(w => Desk.isMin(w))
    readonly property var pinnedList: Store.get("dock.pinned", null) || Prefs.dockApps.map(a => ({ id: a.desktop_id, name: a.name, icon: a.icon }))
    readonly property bool pinned: !!app && pinnedList.some(p => String(p.id).toLowerCase() === String(app.id).toLowerCase())
    function pin() { Store.set("dock.pinned", pinnedList.concat([{ id: app.id, name: app.name, icon: app.icon }])); }
    function unpin() { Store.set("dock.pinned", pinnedList.filter(p => String(p.id).toLowerCase() !== String(app.id).toLowerCase())); }
    function launch() { const e = DesktopEntries.byId(app.id) || DesktopEntries.byId(app.id + ".desktop"); if (e) { Sounds.play("launch"); e.execute(); } }

    readonly property var actions: !app ? [] : [["open_in_new", "New window", "new"],
        [pinned ? "keep_off" : "keep", pinned ? "Unpin from the taskbar" : "Pin to the taskbar", "pin"]]
        .concat(wins.length === 0 ? [] : [
            allMin ? ["open_in_full", "Bring back", "restore"] : ["minimize", wins.length > 1 ? "Minimise all" : "Minimise", "min"],
            ["crop_square", "Maximise", "max"],
            ["close", wins.length > 1 ? "Close " + wins.length + " windows" : "Close window", "close"]])
    function run(what) {
        if (what === "new") launch();
        else if (what === "pin") { if (pinned) unpin(); else pin(); }
        else if (what === "restore") for (const w of wins) Desk.restore(w);
        else if (what === "min") for (const w of wins) { if (!Desk.isMin(w)) Desk.minimize(w); }
        else if (what === "max") Desk.maximize(wins.find(w => w.id === Niri.focusedWindowId) || wins[0]);
        else if (what === "close") for (const w of wins) Desk.close(w);
        HubState.closeDrop();
    }

    SmoothRect {
        id: card
        width: 260
        height: col.implicitHeight + 2 * pad
        readonly property point at: Theme.dropPos(HubState.dropX, HubState.dropY, width, height, dd.width, dd.height)
        x: at.x
        y: at.y
        radius: Theme.corner(80, 14)
        readonly property real pad: Theme.inset(radius, 8)
        color: Theme.frame
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        opacity: dd.shown ? 1 : 0
        scale: dd.shown ? 1 : Theme.popScale
        transformOrigin: Theme.dropOrigin
        Behavior on opacity { Anim { kind: dd.shown ? "enter" : "exit" } }
        Behavior on scale { Anim { kind: dd.shown ? "enter" : "exit" } }
        CardShadow {}
        MouseArea { anchors.fill: parent }

        Column {
            id: col
            x: card.pad; y: card.pad
            width: card.width - 2 * card.pad
            spacing: 2
            Row {
                spacing: 10
                leftPadding: 8; topPadding: 2; bottomPadding: 6
                Image {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 22; height: 22; sourceSize: Qt.size(44, 44)
                    source: dd.app ? (String(dd.app.icon || "").startsWith("/") ? "file://" + dd.app.icon : Quickshell.iconPath(dd.app.icon || "", "application-x-executable")) : ""
                    smooth: true; mipmap: true
                }
                Label { anchors.verticalCenter: parent.verticalCenter; width: col.width - 50; text: dd.app ? dd.app.name : ""; strong: true; elide: Text.ElideRight }
            }
            // its windows, when there's more than one: a click goes to it
            Repeater {
                model: dd.wins.length > 1 ? dd.wins : []
                Pressable {
                    required property var modelData
                    width: col.width; height: 36
                    color: hovered ? Theme.containerHigh : (modelData.id === Niri.focusedWindowId ? Theme.selected : "transparent")
                    onClicked: { Desk.focus(modelData); HubState.closeDrop(); }
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: Desk.isMin(parent.parent.modelData) ? "minimize" : "select_window"; size: 16; color: Theme.subtext }
                        Label { anchors.verticalCenter: parent.verticalCenter; width: col.width - 46; text: parent.parent.modelData.title || dd.app.name; elide: Text.ElideRight; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
            Rectangle { visible: dd.wins.length > 1; width: col.width; height: 1; color: Theme.hairline }
            Repeater {
                model: dd.actions
                Pressable {
                    required property var modelData
                    width: col.width; height: 40
                    color: hovered ? Theme.containerHigh : "transparent"
                    onClicked: dd.run(modelData[2])
                    Row {
                        x: 10; anchors.verticalCenter: parent.verticalCenter; spacing: 10
                        Icon { anchors.verticalCenter: parent.verticalCenter; name: parent.parent.modelData[0]; size: 18; color: parent.parent.modelData[2] === "close" ? Theme.danger : Theme.text }
                        Label { anchors.verticalCenter: parent.verticalCenter; text: parent.parent.modelData[1] }
                    }
                }
            }
        }
    }
}
