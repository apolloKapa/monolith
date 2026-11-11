import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../core"
import "../../ui"
import "../../island"

// The bar as it is now, drawn by the bar itself, on one card: a little monitor showing your
// screen (your wallpaper, two windows, the dock if it's on) with the bar where it sits, top or
// bottom, and under it a close-up of the bar at its real size. Every setting shows in it straight
// away. Nothing in it can be clicked.
Column {
    id: pv
    spacing: 8
    readonly property var scr: Quickshell.screens.find(s => s.name === Niri.focusedOutput) || Quickshell.screens[0]
    readonly property real sw: scr ? scr.width : 1920
    readonly property real sh: scr ? scr.height : 1080

    // the island at rest, the way island/Island.qml draws it
    component Bar: IslandShape {
        id: isl
        property real screenW: pv.sw
        bodyW: Theme.barWidth(screenW, real.needWidth)
        height: Theme.islandH
        r: Theme.fullBar ? (bodyW < screenW - 2 * Theme.barMargin - 1 ? Theme.islandRadius / 2 : 0) : (Theme.square ? 0 : height / 2)
        ear: Theme.fullBar ? 0 : Theme.islandEar
        fill: Theme.barFloats ? "transparent" : (Theme.barOpacity >= 0.99 ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity))
        shadow: !Theme.barFloats && Theme.barOpacity > 0.3
        // Solid: its own rounded floating bar
        Rectangle {
            anchors.fill: parent
            visible: Theme.barStyle === "solid"
            radius: Theme.barRound(height)
            color: Theme.barOpacity >= 0.99 ? Theme.frame : Qt.alpha(Theme.frame, Theme.frame.a * Theme.barOpacity)
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            CardShadow { visible: Theme.barOpacity > 0.3 }
        }
        Item {
            x: isl.e
            width: isl.bodyW
            height: isl.height
            clip: true
            IslandBar {
                id: real
                screenName: pv.scr ? pv.scr.name : ""
                x: Theme.fullBar ? 0 : Math.round((parent.width - width) / 2)
                width: Theme.fullBar ? parent.width : (Theme.barSpread ? Math.max(needWidth, isl.bodyW) : implicitWidth)
            }
        }
    }

    Rectangle {
        id: stage
        width: pv.width
        height: monitor.height + stand.height + 14 + closeUp.height + 34
        radius: Theme.corner(80, 14)
        // a soft spotlight in the accent colour behind the monitor
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.tint(Theme.container, Qt.alpha(Theme.accent, 0.14)) }
            GradientStop { position: 1; color: Theme.container }
        }
        border.width: Theme.outlineW; border.color: Theme.outlineColor

        // ── the monitor: a bezel round your screen, small, on a stand ──
        Rectangle {
            id: monitor
            readonly property real bezel: 7
            // up to 250 px tall (a tall screen is drawn narrower), never wider than the card
            width: Math.min(stage.width - 48, Math.round(250 * pv.sw / pv.sh)) + 2 * bezel
            height: Math.round((width - 2 * bezel) * pv.sh / pv.sw) + 2 * bezel
            anchors.horizontalCenter: parent.horizontalCenter
            y: 18
            radius: Theme.corner(80, 12) + bezel / 2
            color: "#0c0c10"
            border.width: 1; border.color: Qt.alpha("#ffffff", 0.10)
            CardShadow {}

            // (clipped to its rounded shape: a plain clip cuts square corners)
            ClippingRectangle {
                id: screenBox
                x: monitor.bezel; y: monitor.bezel
                width: monitor.width - 2 * monitor.bezel
                height: monitor.height - 2 * monitor.bezel
                radius: Theme.corner(80, 8)
                color: Theme.container
                readonly property real k: width / pv.sw
                readonly property real barTop: Theme.barBottom ? 0 : (Theme.islandH + 2 * Theme.barMargin) * k
                readonly property real barBottomRoom: Theme.barBottom ? (Theme.islandH + 2 * Theme.barMargin) * k : 0
                readonly property bool dockOn: Store.get("dock.enabled", true) !== false && Store.get("dock.position", "bottom") === "bottom"
                Image {
                    anchors.fill: parent
                    source: pv.scr ? Wall.url(Wall.pathFor(pv.scr.name)) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 900
                    asynchronous: true
                }
                // two windows, so the space the bar takes reads as space: each with a title bar
                Repeater {
                    model: [[0.03, 0.6], [0.65, 0.32]]
                    Rectangle {
                        id: win
                        required property var modelData
                        x: screenBox.width * modelData[0]
                        y: screenBox.barTop + 8
                        width: screenBox.width * modelData[1]
                        height: screenBox.height - y - screenBox.barBottomRoom - (screenBox.dockOn && !Theme.barBottom ? 26 : 10)
                        radius: Math.max(4, 12 * screenBox.k)
                        color: Qt.alpha(Theme.m("surface_container_lowest", "#101014"), 0.9)
                        border.width: 1; border.color: Qt.alpha(Theme.text, 0.12)
                        Row {
                            x: 7; y: 6; spacing: 3
                            Repeater { model: ["#ff6159", "#ffbd2e", "#28c941"]; Rectangle { required property string modelData; width: 5; height: 5; radius: 2.5; color: modelData; opacity: 0.85 } }
                        }
                        Column {
                            x: 8; y: 18; spacing: 5
                            Repeater { model: 5; Rectangle { required property int index; width: (index === 0 ? 0.45 : (index % 2 ? 0.7 : 0.55)) * (win.width - 16); height: index === 0 ? 5 : 3; radius: 1.5; color: Qt.alpha(index === 0 ? Theme.accent : Theme.text, index === 0 ? 0.5 : 0.14) } }
                        }
                    }
                }
                // the dock (when it's on, at the bottom)
                Rectangle {
                    visible: screenBox.dockOn && !Theme.barBottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 4 + Number(Store.get("dock.margin", 12)) * screenBox.k
                    width: dockRow.width + 8; height: 14; radius: 7
                    color: Qt.alpha(Theme.card, Math.max(0.35, Number(Store.get("dock.opacity", 1))))
                    border.width: 1; border.color: Qt.alpha(Theme.text, 0.1)
                    Row { id: dockRow; anchors.centerIn: parent; spacing: 3
                        Repeater { model: 7; Rectangle { required property int index; width: 8; height: 8; radius: 4; color: Qt.alpha(index === 2 ? Theme.accent : Theme.text, index === 2 ? 0.9 : 0.35) } } }
                }
                // Frame: the border round the screen
                Rectangle {
                    visible: Theme.barStyle === "frame"
                    anchors.fill: parent
                    color: "transparent"
                    radius: parent.radius
                    border.width: Math.max(1, Theme.frameW * screenBox.k)
                    border.color: Theme.frame
                }
                // the bar, at the screen's scale, where it sits
                Item {
                    width: pv.sw
                    height: Theme.islandH + 20
                    y: Theme.barBottom ? screenBox.height - (Theme.islandH + 2 * Theme.barMargin) * screenBox.k : 0
                    transform: Scale { xScale: screenBox.k; yScale: screenBox.k }
                    Bar { x: Math.round((pv.sw - width) / 2); y: Theme.barMargin; screenW: pv.sw; flipped: Theme.barBottom }
                }
                Rectangle {
                    visible: Store.get("status.autohide", false) === true
                    anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
                    height: 22; width: ah.implicitWidth + 16; radius: 11
                    color: Qt.alpha(Theme.frame, 0.85)
                    Label { id: ah; anchors.centerIn: parent; text: "Hides until the pointer reaches the edge"; font.pixelSize: Theme.sizeSmall - 1 }
                }
                // a little glare over the glass
                Rectangle {
                    anchors.fill: parent
                    radius: parent.radius
                    gradient: Gradient {
                        orientation: Gradient.Horizontal
                        GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.05) }
                        GradientStop { position: 0.35; color: "transparent" }
                    }
                }
            }
        }
        // the stand
        Column {
            id: stand
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: monitor.bottom
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 34; height: 14; color: "#15151b"
                gradient: Gradient { GradientStop { position: 0; color: "#08080c" } GradientStop { position: 1; color: "#1c1c24" } } }
            Rectangle { anchors.horizontalCenter: parent.horizontalCenter; width: 96; height: 5; radius: 2.5; color: "#1c1c24" }
        }

        // ── the bar, close up ──
        ClippingRectangle {
            id: closeUp
            x: 12; width: parent.width - 24
            anchors.top: stand.bottom; anchors.topMargin: 14
            height: Theme.islandH + 28
            radius: Theme.corner(80, 10)
            color: Theme.containerHigh
            Image {
                anchors.fill: parent
                source: pv.scr ? Wall.url(Wall.pathFor(pv.scr.name)) : ""
                fillMode: Image.PreserveAspectCrop
                verticalAlignment: Theme.barBottom ? Image.AlignBottom : Image.AlignTop
                sourceSize.width: 1400
                asynchronous: true
            }
            // the middle of the bar at its real size (a full-width bar is wider than this)
            Item {
                id: close
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(cb.width, parent.width)
                height: parent.height
                readonly property real fit: cb.width > parent.width - 16 && Theme.barLengthMode !== "percent" ? (parent.width - 16) / cb.width : 1
                Bar {
                    id: cb
                    y: Math.min(Theme.barMargin, 12)
                    // a bar against the screen's edge (Fill, Frame, a full-length Island) runs the
                    // close-up's whole width, as it runs the screen's: with a margin each side it
                    // looked like a box floating short of both ends. Floating bars keep a margin.
                    screenW: Theme.barLengthMode === "percent"
                        ? (Theme.barFloats ? Math.max(closeUp.width - 16, (closeUp.width - 16) / Math.max(0.2, Theme.barLength))
                                           : closeUp.width / Math.max(0.2, Theme.barLength))
                        : pv.sw
                    anchors.horizontalCenter: parent.horizontalCenter
                    scale: close.fit
                    transformOrigin: Item.Top
                }
            }
            // Frame: its border down both sides, joined to the bar's band
            Repeater {
                model: Theme.barStyle === "frame" ? [0, 1] : []
                Rectangle {
                    required property int modelData
                    x: modelData === 0 ? 0 : closeUp.width - width
                    y: Theme.islandH
                    width: Math.max(2, Theme.frameW)
                    height: closeUp.height - y
                    color: Theme.liquid ? Qt.alpha(Theme.frame, 0.6) : Theme.frame
                }
            }
            // "close up", in a chip on the left
            Rectangle {
                anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 5
                width: cuLab.implicitWidth + 12; height: 16; radius: 8
                color: Qt.alpha(Theme.frame, 0.8)
                Label { id: cuLab; anchors.centerIn: parent; text: "Real size"; font.pixelSize: Theme.sizeSmall - 2; muted: true }
            }
        }
        Row {
            anchors.left: closeUp.left; anchors.top: closeUp.bottom; anchors.topMargin: 6
            spacing: 6
            Icon { name: "visibility"; size: 14; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            Label { text: "A live preview: it changes as you change the settings below"; muted: true; font.pixelSize: Theme.sizeSmall - 1; anchors.verticalCenter: parent.verticalCenter }
        }
    }
}
