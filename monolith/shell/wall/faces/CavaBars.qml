import QtQuick
import "../../core"
import "../../ui"

// Audio bars from cava: rounded bars (or one smooth filled shape when `continuous`), brighter in
// the middle and fading at the edges. cava only runs while one of these is live and shown.
// How it looks is the widget's own (its settings); what cava hears and how is shared by every
// visualiser (Cava's settings).
Item {
    id: cb
    property bool live: true
    property bool preview: false        // a still curve instead of sound (the editor's palette)
    property bool continuous: false
    property bool mirror: false          // grow up and down from the middle
    property bool flip: false            // grow down from the top
    property int bars: 0                 // how many (0: as many as fit)
    property real spacing: 4
    property real minBar: 6
    property real minLen: 3              // the height of a silent bar
    property real roundness: 1           // 0 square .. 1 fully round ends
    property real scaleY: 1              // how tall the loudest bar gets (1: the widget's height)
    property bool fade: true             // dimmer towards the edges
    property bool dynamic: true          // quiet bars are dimmer too
    property real fill: 0.9              // the continuous shape's strongest opacity
    property int smoothMs: 70            // how fast a bar follows the sound
    property color color: Theme.accent
    property color color2: color         // a second colour: the bars blend into it across the widget
    property int count: bars > 0 ? bars : Math.max(4, Math.min(160, Math.floor((width + spacing) / (minBar + spacing))))
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
    function colourAt(i) { return Qt.tint(cb.color, Qt.alpha(cb.color2, cb.count > 1 ? i / (cb.count - 1) : 0)); }

    Row {
        visible: !cb.continuous
        anchors.bottom: cb.mirror || cb.flip ? undefined : parent.bottom
        anchors.top: cb.flip && !cb.mirror ? parent.top : undefined
        anchors.verticalCenter: cb.mirror ? parent.verticalCenter : undefined
        spacing: cb.spacing
        Repeater {
            model: cb.count
            Rectangle {
                required property int index
                readonly property real v: cb.vals[index] || 0
                readonly property real edge: Math.min(index, cb.count - 1 - index) / Math.max(1, cb.count / 2)
                anchors.bottom: cb.mirror || cb.flip ? undefined : parent.bottom
                anchors.top: cb.flip && !cb.mirror ? parent.top : undefined
                anchors.verticalCenter: cb.mirror ? parent.verticalCenter : undefined
                width: Math.max(1, (cb.width - cb.spacing * (cb.count - 1)) / cb.count)
                height: Math.max(cb.minLen, Math.min(cb.height, v * cb.height * 0.96 * cb.scaleY))
                radius: Math.min(width / 2, height / 2) * cb.roundness
                color: cb.colourAt(index)
                opacity: (cb.dynamic ? 0.3 + 0.7 * v : 1) * (cb.fade ? 0.35 + 0.65 * Math.min(1, edge * 1.6) : 1)
                Behavior on height { enabled: cb.smoothMs > 0; NumberAnimation { duration: cb.smoothMs } }
            }
        }
    }
    Canvas {
        id: smooth
        anchors.fill: parent
        visible: cb.continuous
        property var v: cb.vals
        onVChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const n = v.length;
            if (n < 2) return;
            const step = width / (n - 1);
            const mid = cb.mirror ? height / 2 : (cb.flip ? 0 : height);
            const amp = (cb.mirror ? height / 2 * 0.95 : height * 0.92) * cb.scaleY;
            const dir = cb.flip && !cb.mirror ? -1 : 1;
            const y = i => mid - dir * Math.min(cb.mirror ? height / 2 : height, Math.max(cb.minLen, v[i] * amp));
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
            const edgeA = cb.fade ? 0.25 : cb.fill;
            g.addColorStop(0, Qt.alpha(cb.color, edgeA));
            g.addColorStop(0.5, Qt.alpha(Qt.tint(cb.color, Qt.alpha(cb.color2, 0.5)), cb.fill));
            g.addColorStop(1, Qt.alpha(cb.color2, edgeA));
            c.fillStyle = g;
            c.fill();
        }
    }
}
