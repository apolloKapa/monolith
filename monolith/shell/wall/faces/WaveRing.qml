import QtQuick
import "../../core"
import "../../ui"

// A round gauge: a faint track and an arc up to `value` (0..1) from the top, clockwise. With
// `wavy` the arc ripples like a sine wave (and moves gently while live).
Canvas {
    id: wr
    property real value: 0
    property real thickness: 8          // at a 130 px ring; scales with the ring
    property bool wavy: true
    property color color: Theme.accent
    property color track: Qt.alpha(Theme.text, 0.14)
    property bool live: true
    property real phase: 0
    readonly property real size: Math.min(width, height)
    readonly property real stroke: size * Math.max(3, Math.min(16, thickness)) / 130

    Behavior on value { enabled: wr.live; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    NumberAnimation on phase { from: 0; to: Math.PI * 2; duration: 4000; loops: Animation.Infinite; running: wr.live && wr.wavy && wr.visible }
    onValueChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onWavyChanged: requestPaint()
    onThicknessChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()

    onPaint: {
        const c = getContext("2d");
        c.reset();
        const cx = width / 2, cy = height / 2;
        const amp = wavy ? stroke * 0.55 : 0;
        const r = size / 2 - stroke / 2 - amp - 1;
        c.lineCap = "round";
        c.lineWidth = stroke;
        // track
        c.strokeStyle = track;
        c.beginPath();
        c.arc(cx, cy, r, 0, Math.PI * 2);
        c.stroke();
        const v = Math.max(0, Math.min(1, value));
        if (v <= 0.002) return;
        c.strokeStyle = color;
        c.beginPath();
        const end = v * Math.PI * 2, steps = Math.max(8, Math.round(160 * v)), waves = 12;
        for (let i = 0; i <= steps; i++) {
            const a = end * i / steps;
            const rr = r + amp * Math.sin(a * waves + phase);
            const x = cx + rr * Math.sin(a), y = cy - rr * Math.cos(a);
            if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
        }
        c.stroke();
    }
}
