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
    readonly property color hourC: Theme.m("secondary", Theme.subtext)
    readonly property color minC: Theme.m("primary", Theme.accent)
    readonly property color secC: Theme.m("tertiary", Theme.accent)
    readonly property color numC: Theme.m("on_primary_container", Theme.text)
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
    FrameAnimation { running: f.secs && f.live && f.visible; onTriggered: f.tick() }
    Timer { interval: 1000; running: !f.secs && f.live && f.visible; repeat: true; triggeredOnStart: true; onTriggered: f.tick() }
    Component.onCompleted: tick()

    // the dial: a circle with a soft lobe towards each hour, bigger where it's lit
    Canvas {
        id: dialC
        anchors.fill: parent
        property var g: f.glow
        onGChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        property color c: f.dial
        onCChanged: requestPaint()
        onPaint: {
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
            ctx.fillStyle = c;
            ctx.fill();
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
            visible: lit > 0.001
            x: f.width / 2 + dist * Math.sin(ang * Math.PI / 180) - width / 2
            y: f.height / 2 - dist * Math.cos(ang * Math.PI / 180) - height / 2
            Rectangle { anchors.centerIn: parent; width: parent.width * 0.92; height: width; radius: width / 2; color: parent.col; opacity: parent.lit * 0.24 }
            Text {
                anchors.centerIn: parent
                text: parent.hour
                font.family: Theme.fontFamily; font.pixelSize: f.d * 0.054; font.weight: Font.Bold
                color: parent.lit > 0.5 ? f.numC : parent.col
                opacity: parent.lit
            }
        }
    }
    component Hand: Item {
        property real angle
        property real len
        property color col
        anchors.centerIn: parent
        rotation: angle
        Rectangle { width: f.d * 0.054; height: parent.len; radius: width / 2; color: parent.col; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: -width / 2 }
    }
    Hand { angle: f.hourA; len: f.d * 0.22; col: f.hourC }
    Hand { angle: f.minA; len: f.d * 0.32; col: f.minC }
    Hand { visible: f.secs; angle: f.secA; len: f.d * 0.38; col: f.secC }
}
