import QtQuick
import "../../core"
import "../../ui"

// Liquid in a rounded card, filled to `value` (0–1): up from the bottom, or across from the left
// when `horizontal`. Its surface is one wave, tallest when the card is half full and flat when
// it's empty or full; it moves for a moment after the value changes (or all the time with
// keepMoving), and the liquid is a little lighter towards its surface.
Canvas {
    id: liquid
    antialiasing: true
    property real value: 0
    property bool horizontal: false
    property real radius: 12
    property color color: Theme.accent
    property real maxAmp: 5
    property bool live: true
    property bool keepMoving: false
    property real phase: 0.8
    readonly property real level: Math.max(0, Math.min(1, value))
    readonly property bool partly: level > 0.01 && level < 0.99
    readonly property real amp: partly ? maxAmp * Math.sin(level * Math.PI) : 0

    Behavior on value { enabled: liquid.live; NumberAnimation { duration: Theme.ms(800); easing.type: Easing.OutQuint } }
    // the surface rolls once every 1.8 s while it moves
    NumberAnimation on phase { id: roll; running: false; from: 0; to: 2 * Math.PI; duration: 1800; loops: Animation.Infinite }
    Timer { id: calm; interval: 1800; onTriggered: if (!liquid.keepMoving) roll.stop() }
    function stir() { roll.start(); calm.restart(); }
    onValueChanged: { if (live && partly) stir(); requestPaint(); }
    onKeepMovingChanged: { if (keepMoving && live) roll.start(); else calm.restart(); }
    readonly property var looks: [phase, width, height, color]
    onLooksChanged: requestPaint()

    onPaint: {
        const g = getContext("2d");
        g.reset();
        if (level <= 0.001) return;
        g.save();
        g.beginPath();
        g.roundedRect(0, 0, width, height, radius, radius);
        g.clip();
        // the surface: 48 steps along the card's edge, one whole wave
        const n = 48;
        const wave = i => amp * Math.sin(phase + 2 * Math.PI * i / n);
        g.beginPath();
        if (horizontal) {
            const at = width * level;
            g.moveTo(0, 0);
            for (let i = 0; i <= n; i++) g.lineTo(at + wave(i), height * i / n);
            g.lineTo(0, height);
        } else {
            const at = height * (1 - level);
            g.moveTo(0, height);
            for (let i = 0; i <= n; i++) g.lineTo(width * i / n, at + wave(i));
            g.lineTo(width, height);
        }
        g.closePath();
        const shade = horizontal ? g.createLinearGradient(0, 0, width, 0) : g.createLinearGradient(0, height, 0, 0);
        shade.addColorStop(0, Qt.darker(color, 1.05));
        shade.addColorStop(1, Qt.lighter(color, 1.18));
        g.fillStyle = shade;
        g.fill();
        g.restore();
    }
}
