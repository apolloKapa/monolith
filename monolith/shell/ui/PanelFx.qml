import QtQuick
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
    visible: Theme.fxGrain || Theme.fxEdge || Theme.chamfer
    // the motion: a step every 50 ms, only on panels that come and go (menus), and only while
    // shown. `animate: false` on the ones that are always there (the bar, the dock, the desktop's
    // widgets): their scanlines stay still. (They used to crawl too: the bar and every widget
    // redrawn 20 times a second, all day)
    property bool animate: true
    readonly property bool moving: animate && Theme.chamfer && Theme.animOn && fx.visible && fx.opacity > 0.01
                                   && !!fx.Window.window && fx.Window.window.visible
    property int drift: 0      // scanlines and grain: a pixel a step
    property real sweep: 0     // the scan bar's leading edge: 6 px a step, then a short pause above the panel
    readonly property real barH: Math.min(160, fx.height * 0.45)
    // (from the clock, not counted steps: it always carries on, and every panel sweeps on the same
    // beat, a pass every 4.5 s whatever its height, then a short breath and again. Counted at 6 px
    // a step, a tall panel took 8 s a pass and a long pause, and it looked as if it ran once)
    readonly property real period: 4500
    readonly property real gap: 900
    Timer {
        interval: 50; repeat: true
        running: fx.moving
        onTriggered: {
            const now = Date.now();
            fx.drift = Math.floor(now / 50) % 384;   // a whole number of scanline (3) and grain (128) tiles
            const t = (now % (fx.period + fx.gap)) / fx.period;
            fx.sweep = t <= 1 ? 1 + t * (fx.height + fx.barH) : 0;
        }
    }
    // scanlines, grain and the scan bar: one shader (shaders/panelfx.frag), no offscreen layers
    ShaderEffect {
        anchors.fill: parent
        visible: Theme.chamfer || Theme.fxGrain
        property vector2d itemSize: Qt.vector2d(width, height)
        property real radius: Theme.square ? 0 : fx.radius
        property real cut: Theme.chamfer && fx.radius > 0.5 ? Math.min(Math.min(width, height) / 2, Theme.cut(Math.min(width, height))) : 0
        property real scan: Theme.chamfer ? 0.075 : 0
        property real grain: Theme.fxGrain ? (Theme.dark ? 0.07 : 0.09) : 0
        property real drift: fx.drift
        property real sweep: fx.moving && fx.sweep > 0 && fx.sweep - fx.barH < fx.height ? fx.sweep : 0
        property real barH: fx.barH
        property color accent: Theme.accent
        fragmentShader: Qt.resolvedUrl("shaders/panelfx.frag.qsb")
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
