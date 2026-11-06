import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"

// The Frame bar style: the bar's background along the top and a border round the rest of the
// screen, as one shape (so see-through styles get one even layer, no darker seams where the bar
// meets the border), its inside corners rounded (square in square styles), a soft shadow cast
// inwards onto your windows, the style's outline along the inside edge, and the blur behind it
// in blur styles. Below windows (strips on the edges keep them off it) and click-through; the
// bar's modules sit on top in their own window. Only on screens that have the bar.
Scope {
    id: fr
    required property var modelData
    readonly property bool on: Theme.barStyle === "frame" && (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    readonly property real w: Theme.frameW
    // with auto-hide the bar keeps its own background (it slides away), so the frame starts at 0
    readonly property real top: Theme.frameBand ? Theme.islandH : 0
    readonly property real r: Theme.square ? 0 : Math.max(0, Number(Store.get("bar.frameRadius", Theme.islandRadius)))
    readonly property color col: Theme.barOpacity >= 0.99 ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)

    PanelWindow {
        id: win
        screen: fr.modelData
        visible: fr.on
        WlrLayershell.namespace: "monolith-frame"
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {}

        // the inside (the screen your windows get)
        Item { id: hole; x: fr.w; y: fr.top; width: win.width - 2 * fr.w; height: win.height - fr.top - fr.w }

        // the frame: the screen minus the inside
        Shape {
            id: sh
            anchors.fill: parent
            preferredRendererType: Shape.CurveRenderer
            // the shadow falls inwards, onto the windows
            layer.enabled: Theme.barOpacity > 0.3
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowBlur: Theme.shadowBlur
                shadowColor: Theme.shadowColor
                shadowVerticalOffset: 0
                shadowHorizontalOffset: 0
            }
            ShapePath {
                fillColor: fr.col
                strokeColor: "transparent"
                fillRule: ShapePath.OddEvenFill
                startX: 0; startY: 0
                PathLine { x: sh.width; y: 0 }
                PathLine { x: sh.width; y: sh.height }
                PathLine { x: 0; y: sh.height }
                PathLine { x: 0; y: 0 }
                PathMove { x: hole.x + fr.r; y: hole.y }
                PathLine { x: hole.x + hole.width - fr.r; y: hole.y }
                PathArc { x: hole.x + hole.width; y: hole.y + fr.r; radiusX: fr.r; radiusY: fr.r }
                PathLine { x: hole.x + hole.width; y: hole.y + hole.height - fr.r }
                PathArc { x: hole.x + hole.width - fr.r; y: hole.y + hole.height; radiusX: fr.r; radiusY: fr.r }
                PathLine { x: hole.x + fr.r; y: hole.y + hole.height }
                PathArc { x: hole.x; y: hole.y + hole.height - fr.r; radiusX: fr.r; radiusY: fr.r }
                PathLine { x: hole.x; y: hole.y + fr.r }
                PathArc { x: hole.x + fr.r; y: hole.y; radiusX: fr.r; radiusY: fr.r }
            }
        }
        // the style's outline, along the inside edge only (the outside is the screen's edge)
        Rectangle {
            visible: Theme.outlineW > 0
            x: hole.x - Theme.outlineW / 2; y: hole.y - Theme.outlineW / 2
            width: hole.width + Theme.outlineW; height: hole.height + Theme.outlineW
            radius: fr.r + Theme.outlineW / 2
            color: "transparent"
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
        }

        // blur styles: the wallpaper blurred behind the frame
        BackgroundEffect.blurRegion: Theme.blur ? frameRegion : null
        Region {
            id: frameRegion
            item: win.contentItem
            Region { item: hole; radius: fr.r; intersection: Intersection.Subtract }
        }
    }

    // keep windows off the border
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
