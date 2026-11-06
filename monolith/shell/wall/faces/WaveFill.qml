import QtQuick
import "../../core"
import "../../ui"

// Liquid filling a rounded card: up to `value` (0..1) from the bottom, or from the left when
// `horizontal`, with a wave along its edge that moves for a moment when the value changes.
Canvas {
    id: wf
    property real value: 0
    property bool horizontal: false
    property real radius: 12
    property color color: Theme.accent
    property real maxAmp: 5
    property bool live: true
    property bool keepMoving: false
    property real phase: 0.8
    readonly property real level: Math.max(0, Math.min(1, value))
    readonly property real amp: level > 0.01 && level < 0.99 ? maxAmp * Math.sin(level * Math.PI) : 0

    Behavior on value { enabled: wf.live; NumberAnimation { duration: Theme.ms(800); easing.type: Easing.OutQuint } }
    NumberAnimation on phase { id: move; from: 0; to: Math.PI * 2; duration: 1800; loops: Animation.Infinite; running: false }
    Timer { id: settle; interval: 1800; onTriggered: if (!wf.keepMoving) move.stop() }
    onValueChanged: { if (live && level > 0.01 && level < 0.99) { move.start(); settle.restart(); } requestPaint(); }
    onKeepMovingChanged: if (keepMoving && live) move.start(); else settle.restart()
    onPhaseChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const c = getContext("2d");
        c.reset();
        if (level <= 0.001) return;
        c.save();
        c.beginPath();
        c.roundedRect(0, 0, width, height, radius, radius);
        c.clip();
        const steps = 48;
        c.beginPath();
        if (!horizontal) {
            const top = height * (1 - level);
            c.moveTo(0, height);
            for (let i = 0; i <= steps; i++) {
                const x = width * i / steps;
                c.lineTo(x, top + amp * Math.sin(phase + i / steps * Math.PI * 2));
            }
            c.lineTo(width, height);
        } else {
            const edge = width * level;
            c.moveTo(0, 0);
            for (let i = 0; i <= steps; i++) {
                const y = height * i / steps;
                c.lineTo(edge + amp * Math.sin(phase + i / steps * Math.PI * 2), y);
            }
            c.lineTo(0, height);
        }
        c.closePath();
        const gr = horizontal ? c.createLinearGradient(0, 0, width, 0) : c.createLinearGradient(0, height, 0, 0);
        gr.addColorStop(0, Qt.darker(color, 1.05));
        gr.addColorStop(1, Qt.lighter(color, 1.18));
        c.fillStyle = gr;
        c.fill();
        c.restore();
    }
}
