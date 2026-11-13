import QtQuick
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// The bar down the left or right side of the screen (Settings → Bar → Position): the same
// modules as the top bar (IslandBar, vertical), in the same styles: the island hanging from the
// side edge, a strip along it (Fill, Frame), one floating bar (Solid) or floating sections
// (Modular). Its menus open as floating cards beside it (Island.qml). Like the island's window it
// covers the screen (so drop-downs line up in screen coordinates) and takes clicks only on the bar.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData

    readonly property string side: Theme.barSide
    readonly property bool onLeft: side === "left"
    readonly property bool barHere: (Store.get("bar.hiddenScreens", []) || []).indexOf(modelData.name) === -1
    visible: side !== "" && barHere

    WlrLayershell.namespace: "monolith-sidebar"
    WlrLayershell.layer: WlrLayer.Top
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    // (the bar's part worked out from where the box is: a region handed the click area inside the
    // box only followed that item's own place, so it stayed where the box was when the bar
    // started sliding back in from auto-hide)
    mask: Region {
        item: win.tucked ? sensor : null
        Region {
            x: box.x + hit.x; y: box.y + hit.y
            width: win.tucked ? 0 : hit.width; height: win.tucked ? 0 : hit.height
        }
    }

    // auto-hide (Settings → Bar): it slides off the edge and comes back when the pointer touches it
    readonly property bool autohide: Store.get("status.autohide", false) === true
    readonly property bool tucked: autohide && !sensorHover.hovered && !barHover.hovered && !HubState.open && HubState.dropScreen === ""
    Item {
        id: sensor
        x: win.onLeft ? 0 : win.width - 3
        width: 3; height: win.height
        HoverHandler { id: sensorHover }
    }

    // its thickness, and its length down the edge (as long as its modules need, or its setting)
    readonly property real thick: Theme.islandH
    readonly property real length: Math.min(height - 2 * Theme.barMargin, Theme.barWidth(height, bar.needWidth))
    readonly property bool short: length < height - 2 * Theme.barMargin - 1
    readonly property real ear: Theme.barStyle === "island" ? Math.min(Theme.islandEar, thick / 2) : 0
    readonly property color fill: Theme.barOpacity >= 0.99 ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)
    readonly property bool shadowed: Theme.barOpacity > 0.3

    // the bar's box: off the edge by the floating styles' margin; slid away when tucked
    Item {
        id: box
        readonly property real inset: Theme.barMargin
        readonly property real away: win.tucked ? -(win.thick + inset - 3) : 0
        width: win.thick
        height: win.length
        x: win.onLeft ? inset + away : win.width - width - inset - away
        y: Math.round((win.height - height) / 2)
        Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        Behavior on height { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.sizeCurve } }

        // Island: the top bar's hanging shape, turned to hang from the side edge
        // (turned clockwise its top edge is on the right; anticlockwise, on the left)
        IslandShape {
            id: sideShape
            visible: Theme.barStyle === "island"
            anchors.centerIn: parent
            bodyW: box.height
            height: box.width
            ear: win.ear
            r: Theme.barRound(height)
            rotation: win.onLeft ? -90 : 90
            fill: win.fill
            shadow: win.shadowed
        }
        // Fill (and Frame with auto-hide): a strip along the edge, its inner corners rounded
        // when it's shorter than the screen
        Rectangle {
            id: stripBg
            readonly property real rr: win.short ? Theme.islandRadius / 2 : 0
            visible: Theme.barStyle === "fill" || (Theme.barStyle === "frame" && !Theme.frameBand)
            anchors.fill: parent
            color: win.fill
            topRightRadius: win.onLeft ? rr : 0; bottomRightRadius: win.onLeft ? rr : 0
            topLeftRadius: win.onLeft ? 0 : rr; bottomLeftRadius: win.onLeft ? 0 : rr
            CardShadow { visible: win.shadowed }
        }
        // Solid: one floating rounded bar
        Rectangle {
            visible: Theme.barStyle === "solid"
            anchors.fill: parent
            radius: Theme.barRound(width)
            color: win.fill
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            CardShadow { visible: win.shadowed }
        }

        // what takes the clicks (the bar's box; the island's ears too)
        Item { id: hit; x: -win.ear; y: -win.ear; width: parent.width + 2 * win.ear; height: parent.height + 2 * win.ear; MouseArea { anchors.fill: parent } }
        HoverHandler { id: barHover }

        IslandBar {
            id: bar
            vertical: true
            screenName: win.modelData.name
            trayWindow: win
            width: parent.width
            // a strip spreads its modules from end to end; the island holds them in its middle
            height: Theme.barStyle === "fill" || Theme.barStyle === "frame" ? box.height : (Theme.barSpread ? Math.max(needWidth, box.height) : implicitHeight)
            y: Math.round((box.height - height) / 2)
        }
    }

    // blur behind it (Theme → Effects), shaped like it (the Frame's band blurs behind itself)
    BackgroundEffect.blurRegion: Theme.blur && !Niri.fullscreenOn(modelData.name) && !win.tucked && Theme.barStyle !== "modular" && !(Theme.barStyle === "frame" && Theme.frameBand) ? blurShape : null
    // (cut exactly like what's drawn: a square blur showed as a lighter patch in rounded corners)
    Region {
        id: blurShape
        // Solid: its rounded bar
        Region { item: Theme.barStyle === "solid" ? box : null; radius: Theme.barRound(box.width) }
        // Fill / Frame: the strip, its inner corners rounded when it's shorter than the screen
        Region {
            item: stripBg.visible ? box : null
            topLeftRadius: stripBg.topLeftRadius; topRightRadius: stripBg.topRightRadius
            bottomLeftRadius: stripBg.bottomLeftRadius; bottomRightRadius: stripBg.bottomRightRadius
        }
        // Island: the hanging shape, square against the edge, with its ears
        EdgeBlur {
            on: Theme.barStyle === "island"
            edge: win.onLeft ? "left" : "right"
            bx: box.x; by: box.y; bw: box.width; bh: box.height
            r: sideShape.rr; e: sideShape.e
        }
    }
}
