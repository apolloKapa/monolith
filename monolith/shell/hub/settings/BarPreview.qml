import QtQuick
import Quickshell
import "../../core"
import "../../ui"
import "../../island"

// The bar as it is now, drawn by the bar itself: a small picture of your screen (your wallpaper,
// a couple of windows) with the bar where it sits, and a close-up at its real size. Every
// setting shows in it straight away. Nothing in it can be clicked.
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
        bodyW: Theme.fullBar ? Math.round((screenW - 2 * Theme.barMargin) * Theme.barLength) : Math.max(Theme.islandMinW, real.implicitWidth)
        height: Theme.islandH
        r: Theme.fullBar ? (Theme.barLength < 0.999 ? Theme.islandRadius / 2 : 0) : (Theme.square ? 0 : height / 2)
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
                width: Theme.fullBar ? parent.width : implicitWidth
            }
        }
    }

    // ── your screen, small ──
    Rectangle {
        id: screenBox
        // never taller than 230 px: a tall screen is drawn narrower
        width: Math.min(pv.width, Math.round(230 * pv.sw / pv.sh))
        height: Math.round(width * pv.sh / pv.sw)
        anchors.horizontalCenter: parent.horizontalCenter
        radius: Theme.corner(80, 12)
        color: Theme.container
        clip: true
        readonly property real k: width / pv.sw
        Image {
            anchors.fill: parent
            source: pv.scr ? Wall.url(Wall.pathFor(pv.scr.name)) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize.width: 900
            asynchronous: true
        }
        // two windows, so the space the bar takes reads as space
        Repeater {
            model: [[0.03, 0.62], [0.655, 0.32]]
            Rectangle {
                required property var modelData
                x: screenBox.width * modelData[0]
                y: (Theme.islandH + 16) * screenBox.k + 6
                width: screenBox.width * modelData[1]
                height: screenBox.height - y - 8
                radius: Math.max(3, 12 * screenBox.k)
                color: Qt.alpha(Theme.m("surface_container_lowest", "#101014"), 0.88)
                border.width: 1; border.color: Qt.alpha(Theme.text, 0.12)
                Column {
                    x: 10; y: 10; spacing: 6
                    Repeater { model: 4; Rectangle { required property int index; width: (index % 2 ? 0.35 : 0.55) * 300 * screenBox.k * 2; height: 4; radius: 2; color: Qt.alpha(Theme.text, 0.14) } }
                }
            }
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
        // the bar, at the screen's scale
        Item {
            width: pv.sw
            height: Theme.islandH + 20
            transform: Scale { xScale: screenBox.k; yScale: screenBox.k }
            Bar { x: Math.round((pv.sw - width) / 2); y: Theme.barMargin; screenW: pv.sw }
        }
        Rectangle {
            visible: Store.get("status.autohide", false) === true
            anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 8
            height: 24; width: ah.implicitWidth + 16; radius: 12
            color: Qt.alpha(Theme.frame, 0.85)
            Label { id: ah; anchors.centerIn: parent; text: "Hides until the pointer reaches the top"; font.pixelSize: Theme.sizeSmall - 1 }
        }
    }

    // ── the bar, close up ──
    Rectangle {
        width: pv.width
        height: Theme.islandH + 28
        radius: Theme.corner(80, 12)
        color: Theme.container
        clip: true
        Image {
            anchors.fill: parent
            source: pv.scr ? Wall.url(Wall.pathFor(pv.scr.name)) : ""
            fillMode: Image.PreserveAspectCrop
            verticalAlignment: Image.AlignTop
            sourceSize.width: 1400
            asynchronous: true
        }
        // the middle of the bar at its real size (a full-width bar is wider than this)
        Item {
            id: close
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(cb.width, parent.width)
            height: parent.height
            readonly property real fit: cb.width > parent.width - 16 && !Theme.fullBar ? (parent.width - 16) / cb.width : 1
            Bar {
                id: cb
                y: Math.min(Theme.barMargin, 12)
                screenW: Theme.fullBar ? Math.max(pv.width - 16, (pv.width - 16) / Math.max(0.2, Theme.barLength)) : pv.sw
                anchors.horizontalCenter: parent.horizontalCenter
                scale: close.fit
                transformOrigin: Item.Top
            }
        }
    }
    Label { text: "A live preview: it changes as you change the settings below"; muted: true; font.pixelSize: Theme.sizeSmall }
}
