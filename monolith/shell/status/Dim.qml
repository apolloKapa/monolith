import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// The screens dim a little before the lock comes (Settings → Lock & idle); any movement
// brings them back. Clicks pass through.
PanelWindow {
    required property var modelData
    screen: modelData
    visible: shade.opacity > 0.01
    WlrLayershell.namespace: "monolith-dim"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    mask: Region {}
    Rectangle {
        id: shade
        anchors.fill: parent
        color: "black"
        opacity: Idle.dimming ? 0.55 : 0
        Behavior on opacity { NumberAnimation { duration: Idle.dimming ? 2500 : Theme.ms(250); easing.type: Easing.OutCubic } }
    }
}
