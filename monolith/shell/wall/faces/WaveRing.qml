import QtQuick
import "../../core"
import "../../ui"

// A ring gauge: a full track, and over it an arc from twelve o'clock clockwise to `value` (0–1).
// With `wavy` the ring's line ripples: twelve gentle waves round, about a third of the line's
// width deep (never more than a twentieth of the radius). The line's width is `thickness` at a
// 130 px ring and grows or shrinks with the ring.
Canvas {
    id: gauge
    antialiasing: true
    property real value: 0
    property real thickness: 8
    property bool wavy: true
    property color color: Theme.accent
    property color track: Theme.control
    property bool live: true
    property real phase: 0
    readonly property real size: Math.min(width, height)
    readonly property real stroke: size * Math.max(3, Math.min(16, thickness)) / 130

    Behavior on value { enabled: gauge.live; NumberAnimation { duration: Theme.ms(800); easing.type: Easing.OutQuint } }
    // anything that changes the drawing
    readonly property var looks: [value, phase, wavy, thickness, width, height, color, track]
    onLooksChanged: requestPaint()

    // the line's width, its ripple and the radius it runs at (inside the edge, ripple included)
    function geometry() {
        const edge = size / 2 - 1;
        const line = Math.min(stroke, edge * 0.4);
        let ripple = wavy ? Math.min(line * 0.35, edge * 0.05) : 0;
        const radius = edge - ripple - line / 2;
        return { line: line, ripple: Math.min(ripple, radius * 0.05), radius: radius };
    }
    // the ring's line from twelve o'clock round to `upTo` radians, as a path on g
    function trace(g, geo, upTo) {
        const n = Math.max(8, Math.round(240 * upTo / (2 * Math.PI)));
        g.beginPath();
        for (let i = 0; i <= n; i++) {
            const t = upTo * i / n, r = geo.radius + geo.ripple * Math.sin(12 * t + phase);
            const px = width / 2 + r * Math.sin(t), py = height / 2 - r * Math.cos(t);
            if (i === 0) g.moveTo(px, py); else g.lineTo(px, py);
        }
    }
    onPaint: {
        const g = getContext("2d");
        g.reset();
        const geo = geometry();
        g.lineWidth = geo.line;
        g.lineCap = "round";
        g.lineJoin = "round";
        g.strokeStyle = track;
        trace(g, geo, 2 * Math.PI);
        g.closePath();
        g.stroke();
        const filled = Math.max(0, Math.min(1, value));
        if (filled > 0.001) {
            g.strokeStyle = color;
            trace(g, geo, filled * 2 * Math.PI);
            g.stroke();
        }
    }
}
