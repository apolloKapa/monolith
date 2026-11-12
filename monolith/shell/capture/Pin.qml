import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Widgets
import "../core"
import "../ui"

// A pinned screenshot: stays over your windows on its screen, its own small window. Drag it to
// move it, scroll to make it see-through, double-click (or ✕) to let it go. Hovering shows
// Copy, Edit and ✕. (A fixed-size window: layer windows mustn't be resized while drawing.)
PanelWindow {
    id: win
    required property var modelData       // its id in Capture.pins (ids, so moving one doesn't remake the others)
    readonly property var pin: Capture.pins.find(p => p.id === modelData) || ({ id: modelData, file: "", screen: "", x: 0, y: 0, w: 200, h: 120 })
    screen: Quickshell.screens.find(s => s.name === pin.screen) || Quickshell.screens[0]
    WlrLayershell.namespace: "monolith-pin"
    WlrLayershell.layer: WlrLayer.Top
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; left: true }
    margins { left: px; top: py }
    implicitWidth: pin.w
    implicitHeight: pin.h
    color: "transparent"
    property real px: pin.x
    property real py: pin.y
    property real see: 1

    ClippingRectangle {
        anchors.fill: parent
        radius: 10
        color: Theme.frame
        opacity: win.see
        border.width: 2
        border.color: hov.hovered ? Theme.accent : Qt.alpha(Theme.text, 0.25)
        Image { anchors.fill: parent; anchors.margins: 2; source: Wall.url(win.pin.file); fillMode: Image.PreserveAspectFit; smooth: true; mipmap: true; asynchronous: true }
    }
    HoverHandler { id: hov }
    MouseArea {
        anchors.fill: parent
        cursorShape: pressed ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        property point grab
        onPressed: mouse => grab = Qt.point(mouse.x, mouse.y)
        onPositionChanged: mouse => {
            if (!pressed) return;
            win.px = Math.max(0, Math.min(win.screen.width - 40, win.px + mouse.x - grab.x));
            win.py = Math.max(0, Math.min(win.screen.height - 40, win.py + mouse.y - grab.y));
        }
        onDoubleClicked: Capture.unpin(win.pin.id)
        onWheel: wheel => win.see = Math.max(0.2, Math.min(1, win.see + (wheel.angleDelta.y > 0 ? 0.1 : -0.1)))
    }
    Row {
        visible: hov.hovered
        anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 8
        spacing: 4
        component Act: Pressable {
            property string icon: ""
            width: 30; height: 30; radius: 15
            color: hovered ? Theme.containerHigh : Qt.alpha(Theme.frame, 0.85)
            Icon { anchors.centerIn: parent; name: parent.icon; size: 17 }
        }
        Act { icon: "content_copy"; onClicked: Capture.copyFile(win.pin.file) }
        Act { icon: "edit"; onClicked: Capture.edit(win.pin.file, "") }
        Act { icon: "close"; onClicked: Capture.unpin(win.pin.id) }
    }
}
