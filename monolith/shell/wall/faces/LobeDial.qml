import QtQuick

// A round dial with a wavy edge: its outline is traced point by point round the circle, `steps`
// of them, each at the distance radiusAt(degrees) from the middle (0° is twelve o'clock, going
// clockwise), then filled with `fill` (a colour, or what shade(ctx) gives) and, with a rimWidth,
// edged in rimColor. Call redraw() when what radiusAt or shade read has changed.
Canvas {
    id: lobe
    antialiasing: true
    property int steps: 240
    property var radiusAt: deg => width / 2
    property var shade: null
    property color fill: "white"
    property real rimWidth: 0
    property color rimColor: "transparent"
    function redraw() { requestPaint(); }
    onFillChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const g = getContext("2d");
        g.reset();
        const mx = width / 2, my = height / 2;
        g.beginPath();
        for (let i = 0; i <= steps; i++) {
            const deg = i * 360 / steps, rad = deg * Math.PI / 180, r = radiusAt(deg);
            const px = mx + r * Math.sin(rad), py = my - r * Math.cos(rad);
            if (i === 0) g.moveTo(px, py); else g.lineTo(px, py);
        }
        g.closePath();
        g.fillStyle = shade ? shade(g) : fill;
        g.fill();
        if (rimWidth > 0) { g.lineWidth = rimWidth; g.strokeStyle = rimColor; g.stroke(); }
    }
}
