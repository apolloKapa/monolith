import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"

// Keeps windows clear of the collapsed island: an empty strip along the top edge that only
// reserves space (the island's own window covers the whole screen, so it can't).
PanelWindow {
    id: strip
    required property var modelData
    screen: modelData
    WlrLayershell.namespace: "monolith-reserve"
    WlrLayershell.layer: WlrLayer.Bottom
    anchors { top: !Theme.barBottom; bottom: Theme.barBottom; left: true; right: true }
    implicitHeight: 1
    exclusiveZone: Store.get("status.autohide", false) === true || (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) !== -1 ? 0 : Theme.islandH + Theme.barMargin + 4
    color: "transparent"
    mask: Region {}
    // stay awake (control center), held by the first screen's strip
    IdleInhibitor { window: strip; enabled: Tasks.awake && Quickshell.screens.length > 0 && strip.modelData === Quickshell.screens[0] }
}
