import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The desktop's right-click menu, at the pointer: a row of quick actions (shuffle the
// wallpaper, night light, lock, restart the shell), then the wallpaper picker, the widget
// editor, the theme and Settings. Right-clicking a widget shows that widget instead: its
// style, the editor with it selected, and remove.
PanelWindow {
    id: dm
    required property var modelData
    screen: modelData
    readonly property var at: HubState.deskMenu
    readonly property bool shown: at.screen === modelData.name
    readonly property var item: at.widget !== "" ? WidgetLayout.items("desktop").find(i => i.id === at.widget) || null : null
    visible: shown
    WlrLayershell.namespace: "monolith-desktop-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"

    function run(f) { HubState.closeDeskMenu(); f(); }

    // a click anywhere else closes it
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: HubState.closeDeskMenu() }
    Item { focus: dm.shown; Keys.onEscapePressed: HubState.closeDeskMenu() }

    component Entry: Pressable {
        id: en
        property string icon
        property string text
        property bool danger: false
        width: card.width - 16; height: 40
        color: hovered ? (danger ? Qt.alpha(Theme.danger, 0.16) : Theme.containerHigh) : "transparent"
        Row {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Icon { name: en.icon; size: 19; color: en.danger ? Theme.danger : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            Label { text: en.text; color: en.danger ? Theme.danger : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    component Quick: Pressable {
        property string icon
        property bool on: false
        width: 44; height: 40
        color: on ? Theme.accent : (hovered ? Theme.containerHigh : Theme.container)
        ink: on ? Theme.onAccent : Theme.text
        Icon { anchors.centerIn: parent; name: parent.icon; size: 20; filled: parent.on; color: parent.on ? Theme.onAccent : Theme.text }
    }

    Rectangle {
        id: card
        width: 250
        height: col.implicitHeight + 16
        x: Math.min(dm.at.x, dm.width - width - 8)
        y: Math.min(dm.at.y, dm.height - height - 8)
        radius: Theme.corner(60, 10)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: Theme.shadowY; shadowHorizontalOffset: Theme.shadowX }
        MouseArea { anchors.fill: parent }   // clicks on the card don't close it
        scale: dm.shown ? 1 : 0.9
        opacity: dm.shown ? 1 : 0
        transformOrigin: Item.TopLeft
        Behavior on scale { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }

        Column {
            id: col
            x: 8; y: 8
            spacing: 2

            // ── on a widget ──
            Column {
                visible: !!dm.item
                spacing: 6
                Row {
                    x: 8; spacing: 10
                    Bubble { size: 32; icon: dm.item ? WidgetLayout.typeIcon(dm.item.type) : "widgets" }
                    Label { anchors.verticalCenter: parent.verticalCenter; text: dm.item ? WidgetLayout.typeName(dm.item.type) : ""; strong: true }
                }
                Label { x: 8; visible: dm.item && (WidgetLayout.faces[dm.item.type] || []).length > 1; text: "Style"; muted: true; font.pixelSize: Theme.sizeSmall }
                Dropdown {
                    x: 8
                    width: card.width - 32
                    visible: dm.item && (WidgetLayout.faces[dm.item.type] || []).length > 1
                    opts: dm.item ? (WidgetLayout.faces[dm.item.type] || []) : []
                    value: dm.item ? (dm.item.face || ((WidgetLayout.faces[dm.item.type] || [[""]])[0][0])) : ""
                    onPicked: v => WidgetLayout.update("desktop", dm.item.id, { face: v })
                }
                Item { width: 1; height: 2 }
                Entry { icon: "open_with"; text: "Move & resize"; onClicked: { const id = dm.item.id; dm.run(() => { HubState.editSelect = id; HubState.editWidgetsOn("desktop", dm.modelData.name); }); } }
                Entry { icon: "add"; text: "Add a widget"; onClicked: dm.run(() => HubState.editWidgetsOn("desktop", dm.modelData.name)) }
                Entry { icon: "delete"; text: "Remove this widget"; danger: true; onClicked: { const id = dm.item.id; dm.run(() => WidgetLayout.remove("desktop", id)); } }
            }

            // ── on the desktop ──
            Column {
                visible: !dm.item
                spacing: 2
                Row {
                    x: 0; spacing: 6
                    bottomPadding: 6
                    Quick { icon: "shuffle"; onClicked: dm.run(() => { const l = Wall.images.filter(p => p !== Wall.path); if (l.length) Wall.set(l[Math.floor(Math.random() * l.length)]); }) }
                    Quick { icon: "nightlight"; on: NightLight.enabled; onClicked: NightLight.toggle() }
                    Quick { icon: "lock"; onClicked: dm.run(() => LockState.lock()) }
                    Quick { icon: "refresh"; onClicked: dm.run(() => Quickshell.execDetached(["monolith", "restart"])) }
                }
                Entry { icon: "wallpaper"; text: "Change wallpaper"; onClicked: dm.run(() => HubState.showWall(dm.modelData.name)) }
                Entry { icon: "dashboard_customize"; text: "Edit widgets"; onClicked: dm.run(() => HubState.editWidgetsOn("desktop", dm.modelData.name)) }
                Entry { icon: "palette"; text: "Theme"; onClicked: dm.run(() => HubState.openSettings("style", dm.modelData.name)) }
                Entry { icon: "settings"; text: "Settings"; onClicked: dm.run(() => HubState.openSettings("", dm.modelData.name)) }
            }
        }
    }
}
