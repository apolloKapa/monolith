import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Keeps windows clear of the collapsed island: an empty strip along the top edge that only
// reserves space (the island's own window covers the whole screen, so it can't).
Scope {
    id: res
    required property var modelData
    // no bar on this screen (hidden here, or auto-hide): no strip at all. Changing the zone of a
    // strip that's already there doesn't reach niri (an empty 1 px window never redraws, so the
    // change is never committed) and windows kept stopping short of the top.
    readonly property bool reserves: Store.loaded && Store.get("status.autohide", false) !== true && (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1

    // (along the bar's edge: the top, the bottom or a side. Made anew when the bar moves to
    // another edge, for the same reason)
    Variants {
        model: [Theme.barEdge]
        PanelWindow {
            required property string modelData
            screen: res.modelData
            visible: res.reserves
            WlrLayershell.namespace: "monolith-reserve"
            WlrLayershell.layer: WlrLayer.Bottom
            anchors { top: modelData !== "bottom"; bottom: modelData !== "top"; left: modelData !== "right"; right: modelData !== "left" }
            implicitHeight: 1
            implicitWidth: 1
            exclusiveZone: Theme.islandH + Theme.barMargin + 4
            color: "transparent"
            mask: Region {}
        }
    }

    // stay awake (control center), held by the first screen; reserves nothing
    PanelWindow {
        id: awake
        screen: res.modelData
        visible: Quickshell.screens.length > 0 && res.modelData === Quickshell.screens[0]
        WlrLayershell.namespace: "monolith-awake"
        WlrLayershell.layer: WlrLayer.Background
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; left: true }
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
        IdleInhibitor { window: awake; enabled: Tasks.awake }
    }
}
