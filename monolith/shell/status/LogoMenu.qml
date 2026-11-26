import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The start button's logo, picked from every one there is (holding the start button for a second,
// island/TaskStrip.qml): a card out of the taskbar like an app's menu. Your own distribution's
// first, then the distributions and other systems, then desktops and window managers
// (core/Distro.qml). The one under the pointer is named at the top.
PanelWindow {
    id: dd
    required property var modelData
    screen: modelData
    readonly property bool shown: HubState.dropScreen === modelData.name && HubState.dropKind === "logo" && !HubState.open

    visible: shown || card.opacity > 0.01
    WlrLayershell.namespace: "monolith-logomenu"
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
    onShownChanged: if (shown) { keys.forceActiveFocus(); hoverName = ""; }

    property string hoverName: ""
    readonly property int cols: 9
    readonly property real cell: 44
    function pick(key) {
        if (key === "") Store.unset("desktop.startLogo"); else Store.set("desktop.startLogo", key);
        Store.set("desktop.startIcon", "distro");      // (it showed the grid: the logo now)
        HubState.closeDrop();
    }

    component Tile: Pressable {
        id: tile
        property string key: ""
        property string glyph: ""
        property string label: ""
        readonly property bool current: key === Distro.picked || (key === "" && Distro.picked === "")
        width: dd.cell; height: dd.cell
        radius: Theme.corner(height, 6)
        color: current ? Theme.selected : (hovered ? Theme.containerHigh : "transparent")
        onClicked: dd.pick(key)
        onHoveredChanged: if (hovered) dd.hoverName = label; else if (dd.hoverName === label) dd.hoverName = ""
        Text {
            anchors.centerIn: parent
            text: tile.glyph
            font.family: Distro.fontFamily
            font.pixelSize: 24
            color: tile.current ? Theme.accent : Theme.text
        }
    }

    SmoothRect {
        id: card
        width: dd.cols * dd.cell + (dd.cols - 1) * 4 + 2 * pad
        height: col.implicitHeight + 2 * pad
        readonly property point at: Theme.dropPos(HubState.dropX, HubState.dropY, width, height, dd.width, dd.height)
        x: at.x
        y: at.y
        radius: Theme.corner(80, 14)
        readonly property real pad: Theme.inset(radius, 10)
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
            spacing: 8
            // what's under the pointer, else what it is
            Item {
                width: col.width; height: 28
                Label { anchors.verticalCenter: parent.verticalCenter; x: 4; text: "Start button logo"; strong: true }
                Label {
                    anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 4
                    text: dd.hoverName; muted: true; font.pixelSize: Theme.sizeSmall
                }
            }
            Row {
                spacing: 10
                Tile { key: ""; glyph: Distro.own; label: "Your distribution" + (Distro.name ? " (" + Distro.name + ")" : "") }
                Label { anchors.verticalCenter: parent.verticalCenter; text: "Your distribution"; font.pixelSize: Theme.sizeSmall }
            }
            Label { x: 4; text: "Distributions and systems"; muted: true; font.pixelSize: Theme.sizeSmall }
            Grid {
                columns: dd.cols; spacing: 4
                Repeater {
                    model: Distro.logos.filter(l => l[3] === "os")
                    Tile { required property var modelData; key: modelData[0]; label: modelData[1]; glyph: modelData[2] }
                }
            }
            Label { x: 4; text: "Desktops and window managers"; muted: true; font.pixelSize: Theme.sizeSmall }
            Grid {
                columns: dd.cols; spacing: 4
                Repeater {
                    model: Distro.logos.filter(l => l[3] === "desktop")
                    Tile { required property var modelData; key: modelData[0]; label: modelData[1]; glyph: modelData[2] }
                }
            }
        }
    }
}
