import QtQuick
import QtQuick.Effects
import "../core"

// Theme → Effects on a panel (the open island, floating menus, the dock): film grain over it and a
// light along its top edge. Fill the panel with it, and give it the panel's corner radius.
// The Cyberpunk style adds scanlines and HUD corner marks (a yellow tick along the top past
// the cut corner, a cyan bracket at the bottom right), and its static moves: the scanlines and
// the grain crawl down the panel, and a scan bar (a soft band of the accent with a bright
// leading edge) sweeps down it now and then, like an old CRT.
Item {
    id: fx
    property real radius: 0
    // bar: draw the scan bar here (false where a second PanelFx over the content draws it);
    // barOnly: only the scan bar (that second one, so it sweeps over what's in the panel too)
    property bool bar: true
    property bool barOnly: false
    visible: barOnly ? Theme.chamfer : (Theme.fxGrain || Theme.fxEdge || Theme.chamfer)
    // the motion: a step every 50 ms (so the layers below are redrawn 20 times a second instead
    // of every frame), only while the panel shows
    readonly property bool moving: Theme.chamfer && Theme.animOn && fx.visible
    property int drift: 0      // scanlines and grain: a pixel a step
    property real sweep: 0     // the scan bar's leading edge: 6 px a step, then a short pause above the panel
    readonly property real barH: Math.min(160, fx.height * 0.45)
    Timer {
        interval: 50; repeat: true
        running: fx.moving
        onTriggered: {
            fx.drift = (fx.drift + 1) % 384;   // a whole number of scanline (3) and grain (128) tiles
            fx.sweep = fx.sweep > fx.height + fx.barH + 300 ? 0 : fx.sweep + 6;
        }
    }
    // ── Cyberpunk ──
    Item {
        id: scanSrc
        anchors.fill: parent
        visible: false
        layer.enabled: Theme.chamfer && !fx.barOnly
        clip: true
        Image { x: 0; y: fx.drift % 3 - 3; width: parent.width; height: parent.height + 3; source: "scan.png"; fillMode: Image.Tile; smooth: false }
    }
    MultiEffect {
        anchors.fill: parent
        visible: Theme.chamfer && !fx.barOnly
        source: scanSrc
        opacity: 0.075
        maskEnabled: true
        maskSource: grainMask
    }
    Item {
        id: barSrc
        anchors.fill: parent
        visible: false
        layer.enabled: fx.moving && fx.bar
        clip: true
        Rectangle {
            width: parent.width; height: fx.barH
            y: fx.sweep - height
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 0.8; color: Qt.alpha(Theme.accent, 0.07) }
                GradientStop { position: 0.97; color: Qt.alpha(Theme.accent, 0.16) }
                GradientStop { position: 1; color: Qt.alpha(Theme.accent, 0.35) }
            }
        }
    }
    MultiEffect {
        anchors.fill: parent
        visible: fx.bar && fx.moving && fx.sweep > 0 && fx.sweep - fx.barH < fx.height
        source: barSrc
        maskEnabled: true
        maskSource: grainMask
    }
    Rectangle {
        visible: Theme.chamfer && !fx.barOnly && fx.width > 120
        x: fx.radius + 10; y: 0
        width: 38; height: 2
        color: Theme.c("yellow", Theme.accent)
    }
    Rectangle {
        visible: Theme.chamfer && !fx.barOnly && fx.width > 120 && fx.height > 60
        x: fx.width - fx.radius - 10 - width; y: fx.height - height
        width: 22; height: 2
        color: Theme.accent
    }
    Rectangle {
        visible: Theme.chamfer && !fx.barOnly && fx.width > 120 && fx.height > 60
        x: fx.width - 2; y: fx.height - fx.radius - 10 - height
        width: 2; height: 14
        color: Theme.accent
    }
    // grain: a still noise tile, faint, kept inside the rounded shape
    Item {
        id: grainSrc
        anchors.fill: parent
        visible: false
        layer.enabled: Theme.fxGrain && !fx.barOnly
        clip: true
        Image { x: 0; y: Theme.chamfer ? fx.drift % 128 - 128 : 0; width: parent.width; height: parent.height + (Theme.chamfer ? 128 : 0); source: "grain.png"; fillMode: Image.Tile; smooth: false }
    }
    MultiEffect {
        anchors.fill: parent
        visible: Theme.fxGrain && !fx.barOnly
        source: grainSrc
        opacity: Theme.dark ? 0.07 : 0.09
        maskEnabled: true
        maskSource: grainMask
    }
    SmoothRect { id: grainMask; anchors.fill: parent; radius: fx.radius; visible: false; layer.enabled: Theme.fxGrain || Theme.chamfer }
    // edge: a thin light along the top, brightest in the middle
    Rectangle {
        visible: Theme.fxEdge && !fx.barOnly
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
        visible: Theme.fxEdge && !fx.barOnly
        x: fx.radius; y: 1
        width: parent.width - 2 * x; height: Math.min(28, parent.height / 3)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.10) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
