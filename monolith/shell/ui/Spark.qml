import QtQuick
import "../core"

// A small area graph of `values` (0..1, oldest first), filled under the line.
Canvas {
    id: sp
    property var values: []
    property color color: Theme.accent
    onValuesChanged: requestPaint()
    onColorChanged: requestPaint()
    onPaint: {
        const g = getContext("2d");
        g.reset();
        const n = values.length;
        if (n < 2) return;
        const step = width / 59;
        const x0 = width - (n - 1) * step;
        g.beginPath();
        g.moveTo(x0, height);
        for (let i = 0; i < n; i++) g.lineTo(x0 + i * step, height - Math.max(0, Math.min(1, values[i])) * (height - 2) - 1);
        g.lineTo(width, height);
        g.closePath();
        g.fillStyle = Qt.rgba(sp.color.r, sp.color.g, sp.color.b, 0.22);
        g.fill();
        g.beginPath();
        for (let i = 0; i < n; i++) {
            const x = x0 + i * step, y = height - Math.max(0, Math.min(1, values[i])) * (height - 2) - 1;
            if (i === 0) g.moveTo(x, y); else g.lineTo(x, y);
        }
        g.strokeStyle = sp.color;
        g.lineWidth = 2;
        g.stroke();
    }
}
