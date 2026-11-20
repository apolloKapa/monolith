import QtQuick
import "../core"

// A small area graph of `values` (0..1, oldest first), filled under the line.
Canvas {
    id: sp
    property var values: []
    property color color: Theme.accent
    // its lower corners rounded this much: a graph along the bottom of a rounded card (the
    // card's clip is its square box, so the fill ran out past the card's round corners)
    property real radius: 0
    onRadiusChanged: requestPaint()
    onWidthChanged: requestPaint()
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        const g = getContext("2d");
        g.reset();
        // (a short history, just after the shell starts: drawn across the whole width from its
        // first reading, flat. Drawn as it was, a sliver of graph sat in the corner with a sheer
        // edge down to the bottom, like a page curling up; and the very first reading is often
        // 0, before anything was measured, which made that edge a spike)
        let vals = sp.values.slice();
        if (vals.length > 1 && vals[0] === 0) vals.shift();
        if (vals.length < 2) return;
        while (vals.length < 60) vals.unshift(vals[0]);
        const n = vals.length;
        const r = Math.max(0, Math.min(radius, width / 2, height));
        if (r > 0.5) {
            g.save();
            g.beginPath();
            g.moveTo(0, 0); g.lineTo(width, 0);
            g.lineTo(width, height - r);
            g.arcTo(width, height, width - r, height, r);
            g.lineTo(r, height);
            g.arcTo(0, height, 0, height - r, r);
            g.closePath();
            g.clip();
        }
        const step = width / (n - 1);
        const x0 = 0;
        g.beginPath();
        g.moveTo(x0, height);
        for (let i = 0; i < n; i++) g.lineTo(x0 + i * step, height - Math.max(0, Math.min(1, vals[i])) * (height - 2) - 1);
        g.lineTo(width, height);
        g.closePath();
        g.fillStyle = Qt.rgba(sp.color.r, sp.color.g, sp.color.b, 0.22);
        g.fill();
        g.beginPath();
        for (let i = 0; i < n; i++) {
            const x = x0 + i * step, y = height - Math.max(0, Math.min(1, vals[i])) * (height - 2) - 1;
            if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
        }
        g.strokeStyle = sp.color;
        g.lineWidth = 2;
        g.stroke();
        if (r > 0.5) g.restore();
    }
}
