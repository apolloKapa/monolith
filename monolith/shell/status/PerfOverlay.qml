import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The performance overlay (Gaming page): CPU and GPU load and temperatures in a small pill in
// the top-right corner of the focused screen, over everything (fullscreen games too). It
// doesn't take clicks.
PanelWindow {
    id: ov
    required property var modelData
    screen: modelData
    visible: GameMode.overlay && (Niri.focusedOutput === "" ? modelData === Quickshell.screens[0] : Niri.focusedOutput === modelData.name)
    WlrLayershell.namespace: "monolith-perf"
    WlrLayershell.layer: WlrLayer.Overlay
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; right: true }
    margins { top: 12; right: 12 }
    implicitWidth: pill.width
    implicitHeight: pill.height
    color: "transparent"
    mask: Region {}

    Rectangle {
        id: pill
        width: row.implicitWidth + 24
        height: 34
        radius: 17
        color: Qt.alpha(Theme.frame, 0.82)
        Row {
            id: row
            anchors.centerIn: parent
            spacing: 14
            Repeater {
                model: [["memory", Math.round(Stats.cpu * 100) + "%", Math.round(Stats.temp) + "°"],
                        ["videogame_asset", Math.round(Stats.gpu * 100) + "%", Math.round(Stats.gpuTemp) + "°"],
                        ["bolt", Math.round(Stats.gpuWatts) + " W", ""]]
                Row {
                    required property var modelData
                    spacing: 4
                    Icon { name: modelData[0]; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: modelData[1]; strong: true; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                    Label { visible: modelData[2] !== ""; text: modelData[2]; muted: true; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
