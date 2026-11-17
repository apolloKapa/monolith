import QtQuick
import "../../core"
import "../../ui"

// Lumen: a twelve-lobed dial (primary container) whose lobe at each hour swells as a hand passes
// it; the hand lights that hour's number in its own colour, and it fades again as the hand moves on.
FaceBase {
    id: f
    readonly property real d: Math.min(width, height)
    readonly property bool secs: opt("showSeconds", true)
    readonly property color dial: Theme.m("primary_container", Theme.accentContainer)
    readonly property color hourC: f.hasMain ? f.mainC : Theme.m("secondary", Theme.subtext)
    readonly property color minC: f.hasAccent ? f.accentC : Theme.m("primary", Theme.accent)
    readonly property color secC: f.hasAccent ? f.accentC : Theme.m("tertiary", Theme.accent)
    readonly property color numC: f.hasMain ? f.mainC : Theme.m("on_primary_container", Theme.text)
    property real hourA: 0
    property real minA: 0
    property real secA: 0
    function beam(hand, target, spread) {
        let diff = Math.abs((((hand - target) % 360) + 540) % 360 - 180);
        if (diff >= spread) return 0;
        const c = Math.cos(diff / spread * Math.PI / 2);
        return c * c;
    }
    function tick() {
        const t = new Date(), s = t.getSeconds(), m = t.getMinutes();
        hourA = (t.getHours() % 12) * 30 + m * 0.5 + s / 120;
        minA = m * 6 + s * 0.1;
        secA = (s + t.getMilliseconds() / 1000) * 6;
        const g = [];
        for (let k = 0; k < 12; k++) g.push(Math.max(beam(hourA, k * 30, 45), beam(minA, k * 30, 40), secs ? beam(secA, k * 30, 32) * 0.85 : 0));
        glow = g;
    }
    property var glow: new Array(12).fill(0)
    // the sweeping second hand moves every frame (a 40 ms timer stepped visibly on fast screens);
    // without it, once a second is plenty
    // (30 times a second: a hand turning 6° a second moves a fifth of a degree a step, smooth to
    // the eye; every frame, at 165 Hz, kept the whole desktop redrawing that often)
    Timer { interval: 33; repeat: true; running: f.secs && f.live && f.visible; onTriggered: f.tick() }
    Timer { interval: 1000; running: !f.secs && f.live && f.visible; repeat: true; triggeredOnStart: true; onTriggered: f.tick() }
    Component.onCompleted: tick()

    // the dial: a circle with a soft lobe towards each hour, bigger where it's lit
    Canvas {
        antialiasing: true
        id: dialC
        anchors.fill: parent
        // what it was last painted with: the glow follows the sweeping second hand, so it changes
        // every frame. Painting this canvas (in software) every frame, up to 165 times a second,
        // was most of the shell's CPU with the clock on screen; now it repaints at most 30 times
        // a second, and only when a lobe has visibly changed. (The hands still move every frame)
        property var g: f.glow
        property var painted: []
        property bool dirty: false
        function changed() {
            const a = g, b = painted;
            if (!b || b.length !== a.length) return true;
            for (let i = 0; i < a.length; i++) if (Math.abs(a[i] - b[i]) > 0.012) return true;
            return false;
        }
        onGChanged: { if (!f.secs) requestPaint(); else if (changed()) dirty = true; }
        Timer { interval: 33; repeat: true; running: dialC.dirty && f.live && f.visible; onTriggered: { dialC.dirty = false; dialC.requestPaint(); } }
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        property color c: f.dial
        onCChanged: requestPaint()
        onPaint: {
            painted = g.slice();
            const ctx = getContext("2d");
            ctx.reset();
            const cx = width / 2, cy = height / 2, base = f.d * 0.435, amp = f.d * 0.042;
            ctx.beginPath();
            const n = 360;
            for (let i = 0; i <= n; i++) {
                const deg = i * 360 / n;
                const h = Math.round(deg / 30) % 12;
                let diff = Math.abs(deg - h * 30); if (diff > 180) diff = 360 - diff;
                const bump = 0.5 * (1 + Math.cos(diff / 15 * Math.PI));
                const r = base + amp * (0.28 + 0.72 * (g[h] || 0)) * bump;
                const a = deg * Math.PI / 180;
                const x = cx + r * Math.sin(a), y = cy - r * Math.cos(a);
                if (i === 0) ctx.moveTo(x, y); else ctx.lineTo(x, y);
            }
            ctx.closePath();
            // shaded like a raised disc lit from the top left, a hairline of light round its rim
            const gr = ctx.createRadialGradient(cx - f.d * 0.16, cy - f.d * 0.2, 0, cx, cy, base + amp);
            gr.addColorStop(0, Qt.lighter(c, 1.16));
            gr.addColorStop(0.6, c);
            gr.addColorStop(1, Qt.darker(c, 1.1));
            ctx.fillStyle = gr;
            ctx.fill();
            ctx.lineWidth = Math.max(1, f.d * 0.0035);
            ctx.strokeStyle = Qt.rgba(1, 1, 1, 0.12);
            ctx.stroke();
        }
    }
    Repeater {
        model: 12
        Item {
            required property int index
            readonly property int hour: index + 1
            readonly property real ang: (hour % 12) * 30
            readonly property real ih: f.beam(f.hourA, ang, 45)
            readonly property real im: f.beam(f.minA, ang, 40)
            readonly property real isec: f.secs ? f.beam(f.secA, ang, 32) * 0.85 : 0
            readonly property real lit: Math.max(ih, im, isec)
            readonly property color col: isec >= ih && isec >= im ? f.secC : (im >= ih ? f.minC : f.hourC)
            readonly property real dist: f.d * (0.382 + 0.028 * lit)
            width: f.d * 0.11; height: width
            x: f.width / 2 + dist * Math.sin(ang * Math.PI / 180) - width / 2
            y: f.height / 2 - dist * Math.cos(ang * Math.PI / 180) - height / 2
            Rectangle { anchors.centerIn: parent; width: f.d * (parent.hour % 3 === 0 ? 0.016 : 0.011); height: width; radius: width / 2; color: f.numC; opacity: (1 - parent.lit) * 0.3; antialiasing: true }
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.92; height: width; radius: width / 2; color: parent.col; opacity: parent.lit * 0.24; visible: parent.lit > 0.001 }
            Text { renderType: Text.CurveRendering;
                anchors.centerIn: parent
                text: parent.hour
                font.family: f.fontOr(Theme.fontFamily); font.pixelSize: f.d * 0.054; font.weight: Font.Bold
                color: parent.lit > 0.5 ? f.numC : parent.col
                opacity: parent.lit
                visible: parent.lit > 0.001
            }
        }
    }
    // hands: the hour broad, the minute slimmer, the second a fine line with a short tail; all
    // meet under a cap in the middle
    component Hand: Item {
        property real angle
        property real len
        property real w: f.d * 0.05
        property real tail: 0
        property color col
        anchors.centerIn: parent
        rotation: angle
        Rectangle { width: parent.w; height: parent.len + parent.tail; radius: width / 2; color: parent.col; antialiasing: true
                    anchors.horizontalCenter: parent.horizontalCenter; y: -parent.len }
    }
    Hand { angle: f.hourA; len: f.d * 0.22; w: f.d * 0.06; col: f.hourC }
    Hand { angle: f.minA; len: f.d * 0.32; w: f.d * 0.042; col: f.minC }
    Hand { visible: f.secs; angle: f.secA; len: f.d * 0.37; w: Math.max(2, f.d * 0.014); tail: f.d * 0.07; col: f.secC }
    Rectangle {
        anchors.centerIn: parent
        width: f.d * 0.085; height: width; radius: width / 2; antialiasing: true
        color: f.secs ? f.secC : f.minC
        Rectangle { anchors.centerIn: parent; width: parent.width * 0.4; height: width; radius: width / 2; color: Qt.darker(f.dial, 1.1); antialiasing: true }
    }
}
