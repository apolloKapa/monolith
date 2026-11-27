import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Desktop mode, Hyprland: a window's menu, a right click on its title bar (KDE's "operations
// menu"), by the pointer: minimise, maximise or back, full screen, tile to the left or right half,
// on every workspace, move to another workspace, close (scripts/desk-windows.lua opens it,
// core/Desk.qml does what's picked).
PanelWindow {
    id: wm
    required property var modelData
    screen: modelData
    readonly property var at: Desk.winMenu
    // (on the screen the click was on)
    readonly property bool here: !!at && at.x >= (modelData.x || 0) && at.x < (modelData.x || 0) + modelData.width && at.y >= (modelData.y || 0) && at.y < (modelData.y || 0) + modelData.height
    readonly property bool shown: here
    // (kept while it fades out)
    property var w: ({ addr: "", x: 0, y: 0, max: false, pin: false, title: "" })
    onAtChanged: if (here) w = at
    Component.onCompleted: if (here) w = at

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-window-menu"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: shown ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region { item: wm.shown ? full : none }
    Item { id: full; anchors.fill: parent }
    Item { id: none; width: 0; height: 0 }
    BackgroundEffect.blurRegion: Theme.blur && wm.shown && card.opacity > 0.99 ? blurShape : null
    Region { id: blurShape; item: card; radius: card.radius }

    function close() { Desk.winMenu = null; }
    function run(kind, arg) { const a = w.addr; close(); Desk.winAct(kind, a, arg); }
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; onClicked: wm.close() }
    Item { id: keys; focus: wm.shown; Keys.onEscapePressed: wm.close() }
    onShownChanged: if (shown) keys.forceActiveFocus()

    component Entry: Pressable {
        id: en
        property string icon
        property string text
        property bool danger: false
        width: card.inner; height: 38
        color: hovered ? (danger ? Qt.alpha(Theme.danger, 0.16) : Theme.containerHigh) : "transparent"
        Row {
            x: 12; anchors.verticalCenter: parent.verticalCenter
            spacing: 12
            Icon { name: en.icon; size: 19; color: en.danger ? Theme.danger : Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            Label { text: en.text; color: en.danger ? Theme.danger : Theme.text; anchors.verticalCenter: parent.verticalCenter }
        }
    }
    component Sep: Rectangle { width: card.inner - 16; x: 8; height: 1; color: Qt.alpha(Theme.text, 0.1) }

    SmoothRect {
        id: card
        width: 260
        readonly property real inner: width - 2 * pad
        height: col.implicitHeight + 2 * pad
        // by the pointer, below and to the right of it, kept on the screen
        readonly property real px: wm.w.x - (wm.modelData.x || 0)
        readonly property real py: wm.w.y - (wm.modelData.y || 0)
        x: Math.max(8, Math.min(px + 2, wm.width - width - 8))
        y: py + height + 8 < wm.height ? py + 2 : Math.max(8, py - height - 2)
        radius: Theme.corner(60, 12)
        readonly property real pad: Theme.inset(radius, 6)
        color: Theme.frame
        border.width: Math.max(1, Theme.outlineW); border.color: Theme.outlineW > 0 ? Theme.outlineColor : Theme.hairline
        CardShadow {}
        MouseArea { anchors.fill: parent }
        scale: wm.shown ? 1 : Theme.popScale
        opacity: wm.shown ? 1 : 0
        transformOrigin: Item.TopLeft
        Behavior on opacity { Anim { kind: wm.shown ? "enter" : "exit" } }
        Behavior on scale { Anim { kind: wm.shown ? "enter" : "exit" } }

        Column {
            id: col
            x: card.pad; y: card.pad
            spacing: 2
            Label {
                x: 12; width: card.inner - 24
                topPadding: 4; bottomPadding: 6
                text: wm.w.title || "Window"
                elide: Text.ElideRight
                strong: true
                font.pixelSize: Theme.sizeSmall
                color: Theme.subtext
            }
            Entry { icon: "minimize"; text: "Minimise"; onClicked: wm.run("min") }
            Entry { icon: wm.w.max ? "close_fullscreen" : "crop_square"; text: wm.w.max ? "Restore" : "Maximise"; onClicked: wm.run("max") }
            Entry { icon: "fullscreen"; text: "Full screen"; onClicked: wm.run("full") }
            Sep {}
            Entry { icon: "vertical_split"; text: "Tile to the left"; onClicked: wm.run("left") }
            Entry { icon: "vertical_split"; text: "Tile to the right"; onClicked: wm.run("right") }
            Entry { icon: "push_pin"; text: wm.w.pin ? "Only on this workspace" : "On every workspace"; onClicked: wm.run("pin") }
            // move to a workspace: a row of numbers
            Item {
                width: card.inner; height: 40
                Icon { x: 12; name: "workspaces"; size: 19; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                Row {
                    x: 43; anchors.verticalCenter: parent.verticalCenter
                    spacing: 4
                    Repeater {
                        model: 5
                        Pressable {
                            required property int index
                            width: 32; height: 30; radius: 10
                            color: hovered ? Theme.containerHigh : Qt.alpha(Theme.containerHigh, 0.5)
                            Label { anchors.centerIn: parent; text: String(parent.index + 1); font.pixelSize: Theme.sizeSmall }
                            onClicked: wm.run("ws", index + 1)
                        }
                    }
                }
            }
            Sep {}
            Entry { icon: "close"; text: "Close"; danger: true; onClicked: wm.run("close") }
        }
    }
}
