import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// A delayed screenshot's countdown: a big number in the middle of the screen you're on
// (gone just before the picture is taken). Click it to cancel.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    visible: Capture.countdown > 0 && (Niri.focusedOutput !== "" ? Niri.focusedOutput === modelData.name : modelData === Quickshell.screens[0])
    WlrLayershell.namespace: "monolith-countdown"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.None
    exclusionMode: ExclusionMode.Ignore
    implicitWidth: 140
    implicitHeight: 140
    color: "transparent"
    Rectangle {
        id: dot
        anchors.fill: parent
        radius: width / 2
        color: Qt.alpha(Theme.frame, 0.85)
        border.width: 3; border.color: Theme.accent
        Label { anchors.centerIn: parent; text: Capture.countdown; strong: true; font.pixelSize: 64 }
        Label { anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.bottom; anchors.bottomMargin: 18; text: "click: cancel"; muted: true; font.pixelSize: Theme.sizeTiny }
        MouseArea { anchors.fill: parent; onClicked: Capture.cancelCountdown() }
        scale: 1
        SequentialAnimation on scale { running: win.visible; loops: Animation.Infinite; NumberAnimation { from: 1.08; to: 1; duration: 1000; easing.type: Easing.OutCubic } }
    }
}
