import QtQuick
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../core"

// The Frame bar style: a border round the whole screen in the bar's colour, joined to the bar
// along the top, its inside corners rounded. Click-through; strips on the other three edges
// keep windows clear of it. Only on screens that have the bar.
Scope {
    id: fr
    required property var modelData
    readonly property bool on: Theme.barStyle === "frame" && (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    readonly property real w: Theme.frameW
    readonly property bool hiding: Store.get("status.autohide", false) === true
    readonly property color col: Theme.barOpacity >= 0.99 ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)

    PanelWindow {
        screen: fr.modelData
        visible: fr.on
        WlrLayershell.namespace: "monolith-frame"
        WlrLayershell.layer: WlrLayer.Top
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {}
        Shape {
            id: sh
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            readonly property real t: fr.hiding ? 0 : Theme.islandH - 1          // the bar covers the top
            readonly property real r: Math.max(0, Number(Store.get("bar.frameRadius", Theme.islandRadius)))
            ShapePath {
                fillColor: fr.col
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                // the screen…
                startX: 0; startY: 0
                PathLine { x: sh.width; y: 0 }
                PathLine { x: sh.width; y: sh.height }
                PathLine { x: 0; y: sh.height }
                PathLine { x: 0; y: 0 }
                // …minus the inside, with rounded corners
                PathMove { x: fr.w + sh.r; y: sh.t }
                PathLine { x: sh.width - fr.w - sh.r; y: sh.t }
                PathArc { x: sh.width - fr.w; y: sh.t + sh.r; radiusX: sh.r; radiusY: sh.r }
                PathLine { x: sh.width - fr.w; y: sh.height - fr.w - sh.r }
                PathArc { x: sh.width - fr.w - sh.r; y: sh.height - fr.w; radiusX: sh.r; radiusY: sh.r }
                PathLine { x: fr.w + sh.r; y: sh.height - fr.w }
                PathArc { x: fr.w; y: sh.height - fr.w - sh.r; radiusX: sh.r; radiusY: sh.r }
                PathLine { x: fr.w; y: sh.t + sh.r }
                PathArc { x: fr.w + sh.r; y: sh.t; radiusX: sh.r; radiusY: sh.r }
            }
        }
    }
    // keep windows off the frame
    component Edge: PanelWindow {
        screen: fr.modelData
        visible: fr.on
        WlrLayershell.namespace: "monolith-frame-edge"
        WlrLayershell.layer: WlrLayer.Bottom
        exclusiveZone: fr.w
        implicitWidth: 1
        implicitHeight: 1
        color: "transparent"
        mask: Region {}
    }
    Edge { anchors { left: true; top: true; bottom: true } }
    Edge { anchors { right: true; top: true; bottom: true } }
    Edge { anchors { bottom: true; left: true; right: true } }
}
