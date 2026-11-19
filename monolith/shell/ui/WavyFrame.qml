import QtQuick
import QtQuick.Shapes
import "../core"

// A box whose outline waves (Theme.wavy): what you drag out for a screenshot, a widget's
// frame in the editor. Every side gets a whole number of waves, so they meet in the corners.
Item {
    id: f
    property color color: Theme.accent
    property color fill: "transparent"
    property real lineW: 2
    property real amp: 2.5
    property real wl: 22
    readonly property var pts: {
        const W = width, H = height, out = [];
        if (!visible || W < 2 || H < 2) return [Qt.point(0, 0), Qt.point(0, 0)];
        function side(x0, y0, x1, y1, nx, ny) {
            const L = Math.hypot(x1 - x0, y1 - y0), n = Math.max(1, Math.round(L / wl)), a = Math.min(amp, L / 10);
            const steps = Math.max(4, Math.ceil(L / 2));
            for (let i = 0; i < steps; i++) {
                const t = i / steps, o = a * Math.sin(2 * Math.PI * n * t);
                out.push(Qt.point(x0 + (x1 - x0) * t + nx * o, y0 + (y1 - y0) * t + ny * o));
            }
        }
        side(0, 0, W, 0, 0, -1); side(W, 0, W, H, 1, 0); side(W, H, 0, H, 0, 1); side(0, H, 0, 0, -1, 0);
        out.push(Qt.point(0, 0));
        return out;
    }
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            strokeColor: f.color; strokeWidth: f.lineW; fillColor: f.fill
            joinStyle: ShapePath.RoundJoin; capStyle: ShapePath.RoundCap
            PathPolyline { path: f.pts }
        }
    }
}
