import QtQuick
import "../../core"
import "../../ui"

// Audio bars from cava: rounded bars (or one smooth filled shape when `continuous`), brighter in
// the middle and fading at the edges. cava only runs while one of these is live and shown.
Item {
    id: cb
    property bool live: true
    property bool preview: false        // a still curve instead of sound (the editor's palette)
    property bool continuous: false
    property bool mirror: false          // grow up and down from the middle
    property int count: Math.max(4, Math.min(96, Math.floor((width + spacing) / (minBar + spacing))))
    property real spacing: 4
    property real minBar: 6
    property real minLen: 3
    property color color: Theme.accent
    readonly property bool active: live && visible

    property bool held: false
    function sync() { if (active && !held) { Cava.hold(); held = true; } else if (!active && held) { Cava.release(); held = false; } }
    onActiveChanged: sync()
    Component.onCompleted: sync()
    Component.onDestruction: if (held) Cava.release()

    // cava's bars stretched to `count`, or a still curve in the editor's palette / with no sound
    readonly property var vals: {
        const src = Cava.bars;
        // silence counts as no sound (the editor then shows the still curve, so you see it)
        const quiet = !src.length || src.every(x => x < 0.01);
        const out = [];
        for (let i = 0; i < count; i++) {
            if (quiet || !live) { out.push(preview ? 0.25 + 0.5 * Math.abs(Math.sin(i / 3)) : 0); continue; }
            const p = i / Math.max(1, count - 1) * (src.length - 1);
            const a = Math.floor(p), b = Math.min(src.length - 1, a + 1);
            out.push(src[a] + (src[b] - src[a]) * (p - a));
        }
        return out;
    }

    Row {
        visible: !cb.continuous
        anchors.bottom: cb.mirror ? undefined : parent.bottom
        anchors.verticalCenter: cb.mirror ? parent.verticalCenter : undefined
        spacing: cb.spacing
        Repeater {
            model: cb.count
            Rectangle {
                required property int index
                readonly property real v: cb.vals[index] || 0
                readonly property real edge: Math.min(index, cb.count - 1 - index) / Math.max(1, cb.count / 2)
                anchors.bottom: cb.mirror ? undefined : parent.bottom
                anchors.verticalCenter: cb.mirror ? parent.verticalCenter : undefined
                width: (cb.width - cb.spacing * (cb.count - 1)) / cb.count
                height: Math.max(cb.minLen, v * cb.height * 0.96)
                radius: Math.min(width * 0.35, height / 2)
                color: cb.color
                opacity: (0.3 + 0.7 * v) * (0.35 + 0.65 * Math.min(1, edge * 1.6))
                Behavior on height { NumberAnimation { duration: 70 } }
            }
        }
    }
    Canvas {
        id: smooth
        anchors.fill: parent
        visible: cb.continuous
        property var v: cb.vals
        onVChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const n = v.length;
            if (n < 2) return;
            const step = width / (n - 1);
            const mid = cb.mirror ? height / 2 : height;
            const amp = cb.mirror ? height / 2 * 0.95 : height * 0.92;
            const y = i => mid - Math.max(cb.minLen / amp, v[i]) * amp;
            c.beginPath();
            c.moveTo(0, mid);
            c.lineTo(0, y(0));
            for (let i = 1; i < n; i++) { const mx = (i - 0.5) * step; c.bezierCurveTo(mx, y(i - 1), mx, y(i), i * step, y(i)); }
            if (cb.mirror) {
                const yb = i => mid + (mid - y(i));
                c.lineTo(width, yb(n - 1));
                for (let i = n - 2; i >= 0; i--) { const mx = (i + 0.5) * step; c.bezierCurveTo(mx, yb(i + 1), mx, yb(i), i * step, yb(i)); }
            } else c.lineTo(width, mid);
            c.closePath();
            const g = c.createLinearGradient(0, 0, width, 0);
            g.addColorStop(0, Qt.alpha(cb.color, 0.25));
            g.addColorStop(0.5, Qt.alpha(cb.color, 0.9));
            g.addColorStop(1, Qt.alpha(cb.color, 0.25));
            c.fillStyle = g;
            c.fill();
        }
    }
}
