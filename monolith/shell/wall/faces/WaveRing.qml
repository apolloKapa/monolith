import QtQuick
import "../../core"
import "../../ui"

// A round gauge: a track and an arc up to `value` (0..1) from the top, clockwise. With `wavy`
// both ripple gently (twelve waves round, a third of the line's width deep), standing still.
Canvas {
    id: wr
    property real value: 0
    property real thickness: 8          // at a 130 px ring; scales with the ring
    property bool wavy: true
    property color color: Theme.accent
    property color track: Theme.control
    property bool live: true
    property real phase: 0
    readonly property real size: Math.min(width, height)
    readonly property real stroke: size * Math.max(3, Math.min(16, thickness)) / 130

    Behavior on value { enabled: wr.live; NumberAnimation { duration: 800; easing.type: Easing.OutQuint } }
    onValueChanged: requestPaint()
    onPhaseChanged: requestPaint()
    onWavyChanged: requestPaint()
    onThicknessChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onColorChanged: requestPaint()

    onTrackChanged: requestPaint()
    onPaint: {
        const c = getContext("2d");
        c.reset();
        const cx = width / 2, cy = height / 2;
        const outer = size / 2 - 1;
        const sw = Math.min(stroke, outer * 0.4);
        let amp = wavy ? Math.min(sw * 0.35, outer * 0.05) : 0;
        const r = outer - amp - sw / 2;
        amp = Math.min(amp, r * 0.05);
        c.lineCap = "round";
        c.lineJoin = "round";
        c.lineWidth = sw;
        function path(to) {
            const steps = Math.max(8, Math.round(240 * to / (Math.PI * 2)));
            c.beginPath();
            for (let i = 0; i <= steps; i++) {
                const a = to * i / steps;
                const rr = r + amp * Math.sin(a * 12 + phase);
                const x = cx + rr * Math.sin(a), y = cy - rr * Math.cos(a);
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
        }
        c.strokeStyle = track;
        path(Math.PI * 2);
        c.closePath();
        c.stroke();
        const v = Math.max(0, Math.min(1, value));
        if (v <= 0.001) return;
        c.strokeStyle = color;
        path(v * Math.PI * 2);
        c.stroke();
    }
}
