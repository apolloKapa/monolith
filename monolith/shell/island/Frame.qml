import QtQuick
import QtQuick.Shapes
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

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
    // (down a side with auto-hide the bar keeps its own background and slides away, so the frame
    // starts at 0 there)
    readonly property real top: Theme.frameBand ? Theme.islandH : 0
    // auto-hide along the top or bottom: the bar's own window draws the whole frame (its edge
    // moves with the bar: island/Island.qml), so nothing is drawn here; the strips below still
    // keep windows off the border
    readonly property bool open: Theme.frameHide
    readonly property real r: Theme.frameRadius
    readonly property color col: Theme.frameFill

    PanelWindow {
        id: win
        screen: fr.modelData
        visible: fr.on && !fr.open
        WlrLayershell.namespace: "monolith-frame"
        WlrLayershell.layer: WlrLayer.Bottom
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: "transparent"
        mask: Region {}

        // the inside (the screen your windows get)
        // (the bar's band is along the bottom when the bar is)
        // (or down the side, with a bar there)
        readonly property string band: Theme.barEdge
        Item {
            id: hole
            x: win.band === "left" ? fr.top : fr.w
            y: win.band === "top" ? fr.top : fr.w
            width: win.width - (win.band === "left" || win.band === "right" ? fr.top + fr.w : 2 * fr.w)
            height: win.height - (win.band === "top" || win.band === "bottom" ? fr.top + fr.w : 2 * fr.w)
        }

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
        // the outline (the style's, or the one picked in Settings → Bar), along the inside edge
        // only (the outside is the screen's edge)
        FrameLine {
            anchors.fill: parent
            hx: hole.x; hy: hole.y; hw: hole.width; hh: hole.height
            r: fr.r; lw: Theme.frameOutlineW; lineColor: Theme.frameOutlineColor
            gap: HubState.frameGapOn(fr.modelData.name)
        }

        // blur styles: the wallpaper blurred behind the frame
        BackgroundEffect.blurRegion: Theme.blur && !Intro.playing ? frameRegion : null
        // Smooth sailing (core/Intro): the frame fades in with the bar
        Binding { target: win.contentItem; property: "opacity"; value: Intro.barK; when: Intro.playing; restoreMode: Binding.RestoreBindingOrValue }
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
    // auto-hide, the bar out: windows move out of its way and back, as they would for a frame
    // growing a bar (they were covered by it: the top of every window, cut off under the bar).
    // A strip of its own, there only while the bar is out: a strip that's already there doesn't
    // get a new size through to the compositor (see Reserve.qml). On top of the border's strip,
    // so the two add up to the bar's height
    Variants {
        model: fr.open && HubState.barOut[fr.modelData.name] === true ? [Theme.barEdge] : []
        PanelWindow {
            required property string modelData
            screen: fr.modelData
            visible: fr.on
            WlrLayershell.namespace: "monolith-frame-bar"
            WlrLayershell.layer: WlrLayer.Bottom
            anchors { left: true; right: true; top: modelData === "top"; bottom: modelData === "bottom" }
            exclusiveZone: Math.max(1, Theme.islandH - fr.w)
            implicitWidth: 1
            implicitHeight: 1
            color: "transparent"
            mask: Region {}
        }
    }
    // (on the three edges the bar isn't on: Reserve keeps them off the bar's. With auto-hide
    // nothing is reserved for the bar, so its edge gets a strip for the border too)
    Variants {
        model: ["left", "right", "top", "bottom"].filter(e => fr.open || e !== Theme.barEdge)
        Edge {
            required property string modelData
            anchors { left: modelData !== "right"; right: modelData !== "left"; top: modelData !== "bottom"; bottom: modelData !== "top" }
        }
    }
}
