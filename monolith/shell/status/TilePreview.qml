import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Desktop mode, Hyprland: where a window being dragged will go when you let go (KDE's quick tile
// outline): the half, the quarter or the whole screen, frosted and edged in the accent. It comes
// out of the edge the pointer is at, moves to the next zone as the pointer does, and fades as the
// window takes its place. Clicks go through it (scripts/desk-windows.lua says where, core/Desk.qml).
PanelWindow {
    id: tp
    required property var modelData
    screen: modelData
    readonly property var p: Desk.preview
    // (the outline in this screen's own coordinates; a zone is always on one screen)
    readonly property real lx: p.x - (modelData.x || 0)
    readonly property real ly: p.y - (modelData.y || 0)
    readonly property bool here: p.w > 0 && lx >= -1 && ly >= -1 && lx + p.w <= modelData.width + 1 && ly + p.h <= modelData.height + 1
    readonly property bool shown: p.on && here

    visible: shown || box.opacity > 0.01
    WlrLayershell.namespace: "monolith-tile-preview"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // (no input at all: a zero-size item, a null one caught every click)
    mask: Region { item: none }
    Item { id: none; width: 0; height: 0 }
    BackgroundEffect.blurRegion: Theme.blur && tp.shown && box.opacity > 0.9 ? blurShape : null
    Region { id: blurShape; item: box; radius: box.radius }

    // where it was last: it fades out there instead of jumping to nothing
    property real bx: 0
    property real by: 0
    property real bw: 0
    property real bh: 0
    onShownChanged: if (shown) place(false)
    onLxChanged: if (shown) place(true)
    onLyChanged: if (shown) place(true)
    Connections { target: Desk; function onPreviewChanged() { if (tp.shown) tp.place(true); } }
    function place(glide) {
        geo.enabled = glide;
        if (!glide) {
            // (coming in: from a little smaller, on the side of the edge it's at)
            const k = 0.92;
            bx = lx + p.w * (1 - k) * (lx <= 8 ? 0 : (lx + p.w >= width - 8 ? 1 : 0.5));
            by = ly + p.h * (1 - k) * (ly <= 8 ? 0 : (ly + p.h >= height - 8 ? 1 : 0.5));
            bw = p.w * k; bh = p.h * k;
            geo.enabled = true;
        }
        bx = lx; by = ly; bw = p.w; bh = p.h;
    }
    QtObject { id: geo; property bool enabled: false }

    Rectangle {
        id: box
        x: tp.bx; y: tp.by; width: tp.bw; height: tp.bh
        Behavior on x { enabled: geo.enabled; Anim { kind: "standard" } }
        Behavior on y { enabled: geo.enabled; Anim { kind: "standard" } }
        Behavior on width { enabled: geo.enabled; Anim { kind: "standard" } }
        Behavior on height { enabled: geo.enabled; Anim { kind: "standard" } }
        radius: Theme.corner(48, 10)
        color: Qt.alpha(Theme.accent, 0.13)
        border.width: 2
        border.color: Qt.alpha(Theme.accent, 0.75)
        opacity: tp.shown ? 1 : 0
        Behavior on opacity { Anim { kind: tp.shown ? "enter" : "exit" } }
        // a softer second edge inside, like a pane of glass
        Rectangle {
            anchors.fill: parent; anchors.margins: 5
            radius: Math.max(0, parent.radius - 5)
            color: "transparent"
            border.width: 1
            border.color: Qt.alpha(Theme.accent, 0.25)
        }
    }
}
