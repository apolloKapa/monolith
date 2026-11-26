import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The bar's menu: a click on an empty part of the bar (or the taskbar in Desktop mode), by the
// pointer. Its size and when it shows right here; its pills and layout, the mini bars, the dock's
// apps and Desktop mode's start button a click away. On a mini bar: that mini bar's size, when it
// shows, moving it and taking it away.
PanelWindow {
    id: bm
    required property var modelData
    screen: modelData
    readonly property var at: HubState.barMenu
    readonly property bool shown: at.screen === modelData.name
    // (kept while it fades out, when the menu's place is already cleared)
    property int mini: -1
    property point spot: Qt.point(0, 0)
    onAtChanged: if (at.screen === modelData.name) { mini = at.mini; spot = Qt.point(at.x, at.y); }
    Component.onCompleted: if (at.screen === modelData.name) { mini = at.mini; spot = Qt.point(at.x, at.y); }

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-bar-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: bm.shown ? full : null }
    Item { id: full; anchors.fill: parent }
    BackgroundEffect.blurRegion: Theme.blur && bm.shown && card.opacity > 0.99 ? blurShape : null
    Region { id: blurShape; item: card; radius: card.radius }

    function run(f) { HubState.closeBarMenu(); f(); }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: HubState.closeBarMenu() }
    Item { id: keys; focus: bm.shown; Keys.onEscapePressed: HubState.closeBarMenu() }
    onShownChanged: if (shown) keys.forceActiveFocus()

    // the mini bar it's for, and changing it
    readonly property var minis: { const v = Store.get("bar.minis", []); return v && v.length !== undefined ? Array.prototype.slice.call(v) : []; }
    readonly property var miniBar: mini >= 0 && mini < minis.length ? minis[mini] : null
    readonly property real miniK: miniBar && Number(miniBar.scale) > 0 ? Math.max(0.6, Math.min(1.6, Number(miniBar.scale))) : 1
    function setMini(k, v) {
        const l = JSON.parse(JSON.stringify(minis));
        if (!l[mini]) return;
        l[mini][k] = v;
        Store.set("bar.minis", l);
    }
    function removeMini() {
        const l = JSON.parse(JSON.stringify(minis));
        l.splice(mini, 1);
        Store.set("bar.minis", l);
    }
    readonly property bool dockThere: Desk.on || Store.get("dock.enabled", true) !== false

    component Entry: Pressable {
        id: en
        property string icon
        property string text
        property bool danger: false
        width: card.inner; height: 40
        color: hovered ? (danger ? Qt.alpha(Theme.danger, 0.16) : Theme.containerHigh) : "transparent"
        Row {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Icon { name: en.icon; size: 19; color: en.danger ? Theme.danger : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            Label { text: en.text; color: en.danger ? Theme.danger : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    component Line: Item {
        property string text
        default property alias content: slot.data
        width: card.inner; height: 44
        Label { x: 12; anchors.verticalCenter: parent.verticalCenter; text: parent.text; font.pixelSize: Theme.sizeSmall }
        Item { id: slot; anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter; width: childrenRect.width; height: childrenRect.height }
    }

    SmoothRect {
        id: card
        width: 300
        readonly property real inner: width - 2 * pad
        height: col.implicitHeight + 2 * pad
        // by the pointer: above it with the bar at the bottom, below it with the bar at the top
        x: Math.max(8, Math.min(bm.spot.x - width / 2, bm.width - width - 8))
        y: bm.spot.y > bm.height / 2 ? Math.max(8, bm.spot.y - height - 14) : Math.min(bm.spot.y + 14, bm.height - height - 8)
        radius: Theme.corner(60, 12)
        readonly property real pad: Theme.inset(radius, 8)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
        MouseArea { anchors.fill: parent }   // clicks on the card don't close it
        scale: bm.shown ? 1 : Theme.popScale
        opacity: bm.shown ? 1 : 0
        transformOrigin: bm.spot.y > bm.height / 2 ? Item.Bottom : Item.Top
        Behavior on opacity { Anim { kind: bm.shown ? "enter" : "exit" } }
        Behavior on scale { Anim { kind: bm.shown ? "enter" : "exit" } }

        Column {
            id: col
            x: card.pad; y: card.pad
            spacing: 2
            Row {
                x: 8; spacing: 10; bottomPadding: 6; topPadding: 2
                Bubble { size: 32; icon: bm.mini >= 0 ? "view_agenda" : (Desk.on ? "dock_to_bottom" : "toolbar") }
                Label { anchors.verticalCenter: parent.verticalCenter; strong: true
                        text: bm.mini >= 0 ? "Mini bar " + (bm.mini + 1) : (Desk.on ? "Taskbar" : "Bar") }
            }

            // ── the bar (or Desktop mode's taskbar) ──
            Column {
                visible: bm.mini < 0
                spacing: 2
                Line {
                    text: "Size"
                    NumberBox { width: 200; from: Desk.on ? 40 : 28; to: 72; step: 2; unit: "px"; value: Theme.islandH; onMoved: v => Store.set(Desk.on ? "desktop.height" : "bar.height", v) }
                }
                Line {
                    text: "When it shows"
                    Dropdown {
                        width: 170
                        opts: [["always", "Always", "Windows keep clear of it"], ["dodge", "Dodge windows", "Out of the way while a window is where it sits"],
                               ["edge", "At the edge", "Auto-hide: away until you touch its edge"]]
                        value: Theme.barShow
                        onPicked: v => { Store.set("bar.show", v); Store.set("status.autohide", v === "edge"); }
                    }
                }
                Item { width: 1; height: 4 }
                Entry { icon: "view_week"; text: "Pills & layout"; onClicked: bm.run(() => HubState.openSettings("bar", bm.modelData.name)) }
                Entry { icon: "view_agenda"; text: "Mini bars"; onClicked: bm.run(() => HubState.openSettings("minibars", bm.modelData.name)) }
                Entry { visible: bm.dockThere; icon: "apps"; text: Desk.on ? "Edit the taskbar's apps" : "Edit the dock"; onClicked: bm.run(() => HubState.editDock(bm.modelData.name)) }
                Entry {
                    visible: Desk.on; icon: "grid_view"; text: "Start button logo"
                    onClicked: { const p = bm.spot; bm.run(() => HubState.toggleDrop("logo", bm.modelData.name, p.x, p.y)); }
                }
                Entry { visible: Desk.experimental; icon: "desktop_windows"; text: "Desktop mode"; onClicked: bm.run(() => HubState.openSettings("desktopmode", bm.modelData.name)) }
                Entry { icon: "settings"; text: "Bar settings"; onClicked: bm.run(() => HubState.openSettings("bar", bm.modelData.name)) }
            }

            // ── a mini bar ──
            Column {
                visible: bm.mini >= 0
                spacing: 2
                Line {
                    text: "Size"
                    Slider {
                        width: 170; implicitHeight: 36
                        icon: "zoom_in"
                        value: (bm.miniK - 0.6) / 1.0
                        label: Math.round(bm.miniK * 100) + "%"
                        onMoved: v => { const k = Math.round((0.6 + v * 1.0) * 100) / 100; if (Math.abs(k - bm.miniK) > 0.001) bm.setMini("scale", k); }
                        onIconClicked: bm.setMini("scale", 1)
                    }
                }
                Line {
                    text: "When it shows"
                    Dropdown {
                        width: 170
                        opts: [["bar", "Like the bar", "Goes away and comes back with the bar"], ["always", "Always", "There all the time"],
                               ["dodge", "Dodge windows", "Out of the way while a window is where it sits"], ["edge", "At its edge", "Away until you touch its edge"]]
                        value: bm.miniBar && ["always", "dodge", "edge"].indexOf(String(bm.miniBar.show || "")) !== -1 ? String(bm.miniBar.show) : "bar"
                        onPicked: v => bm.setMini("show", v)
                    }
                }
                Item { width: 1; height: 4 }
                Entry { icon: "open_with"; text: "Move it"; onClicked: bm.run(() => HubState.editMinis(bm.modelData.name)) }
                Entry { icon: "widgets"; text: "What's in it"; onClicked: bm.run(() => HubState.openSettings("minibars", bm.modelData.name)) }
                Entry { icon: "delete"; text: "Remove this mini bar"; danger: true; onClicked: bm.run(() => bm.removeMini()) }
            }
        }
    }
}
