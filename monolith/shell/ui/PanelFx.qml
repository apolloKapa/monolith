import QtQuick
import QtQuick.Effects
import "../core"

// Theme → Effects on a panel (the open island, floating menus, the dock): film grain over it and a
// light along its top edge. Fill the panel with it, and give it the panel's corner radius.
// The Cyberpunk style adds faint scanlines and HUD corner marks (a yellow tick along the top past
// the cut corner, a cyan bracket at the bottom right), and its static (the scanlines and the
// grain) crawls slowly down the panel.
Item {
    id: fx
    property real radius: 0
    visible: Theme.fxGrain || Theme.fxEdge || Theme.chamfer
    // the crawl: a pixel every 80 ms (in steps, so the layers below are redrawn 12 times a second
    // instead of every frame), only while the panel shows
    property int drift: 0
    Timer {
        interval: 80; repeat: true
        running: Theme.chamfer && Theme.animOn && fx.visible
        onTriggered: fx.drift = (fx.drift + 1) % 384   // a whole number of scanline (3) and grain (128) tiles
    }
    // ── Cyberpunk ──
    Item {
        id: scanSrc
        anchors.fill: parent
        visible: false
        layer.enabled: Theme.chamfer
        clip: true
        Image { x: 0; y: fx.drift % 3 - 3; width: parent.width; height: parent.height + 3; source: "scan.png"; fillMode: Image.Tile; smooth: false }
    }
    MultiEffect {
        anchors.fill: parent
        visible: Theme.chamfer
        source: scanSrc
        opacity: 0.035
        maskEnabled: true
        maskSource: grainMask
    }
    Rectangle {
        visible: Theme.chamfer && fx.width > 120
        x: fx.radius + 10; y: 0
        width: 38; height: 2
        color: Theme.c("yellow", Theme.accent)
    }
    Rectangle {
        visible: Theme.chamfer && fx.width > 120 && fx.height > 60
        x: fx.width - fx.radius - 10 - width; y: fx.height - height
        width: 22; height: 2
        color: Theme.accent
    }
    Rectangle {
        visible: Theme.chamfer && fx.width > 120 && fx.height > 60
        x: fx.width - 2; y: fx.height - fx.radius - 10 - height
        width: 2; height: 14
        color: Theme.accent
    }
    // grain: a still noise tile, faint, kept inside the rounded shape
    Item {
        id: grainSrc
        anchors.fill: parent
        visible: false
        layer.enabled: Theme.fxGrain
        clip: true
        Image { x: 0; y: Theme.chamfer ? fx.drift % 128 - 128 : 0; width: parent.width; height: parent.height + (Theme.chamfer ? 128 : 0); source: "grain.png"; fillMode: Image.Tile; smooth: false }
    }
    MultiEffect {
        anchors.fill: parent
        visible: Theme.fxGrain
        source: grainSrc
        opacity: Theme.dark ? 0.07 : 0.09
        maskEnabled: true
        maskSource: grainMask
    }
    SmoothRect { id: grainMask; anchors.fill: parent; radius: fx.radius; visible: false; layer.enabled: Theme.fxGrain || Theme.chamfer }
    // edge: a thin light along the top, brightest in the middle
    Rectangle {
        visible: Theme.fxEdge
        x: fx.radius * 0.6; y: 0.5
        width: parent.width - 2 * x; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.accent, 0.85) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        visible: Theme.fxEdge
        x: fx.radius; y: 1
        width: parent.width - 2 * x; height: Math.min(28, parent.height / 3)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.10) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
