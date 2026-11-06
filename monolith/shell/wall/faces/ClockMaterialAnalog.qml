import QtQuick
import QtQuick.Shapes
import "../../core"
import "../../ui"

// Material analog: a scalloped dial (twelve soft lobes) in the primary container colour, thick
// rounded hour and minute hands, and the second as a dot near the rim that stretches into a short
// arc to the next second (its front leads, its back catches up).
FaceBase {
    id: f
    readonly property real d: Math.min(width, height)
    readonly property bool secs: opt("showSeconds", true)
    readonly property color dial: Theme.m("primary_container", Theme.accentContainer)
    readonly property color hourC: f.hasMain ? f.mainC : Theme.m("secondary", Theme.subtext)
    readonly property color minC: f.hasAccent ? f.accentC : Theme.m("primary", Theme.accent)
    readonly property color secC: f.hasAccent ? f.accentC : Theme.m("tertiary", Theme.accent)
    Canvas {
        anchors.centerIn: parent
        width: f.d; height: f.d
        property color fill: f.dial
        onFillChanged: requestPaint()
        onWidthChanged: requestPaint()
        onPaint: {
            const c = getContext("2d");
            c.reset();
            const cx = width / 2, cy = height / 2, rm = width * 0.46, amp = width * 0.012;
            c.beginPath();
            for (let i = 0; i <= 240; i++) {
                const a = i / 240 * Math.PI * 2, r = rm + amp * Math.cos(12 * a);
                const x = cx + r * Math.sin(a), y = cy - r * Math.cos(a);
                if (i === 0) c.moveTo(x, y); else c.lineTo(x, y);
            }
            c.closePath();
            c.fillStyle = fill;
            c.fill();
        }
    }
    component Hand: Item {
        property real angle
        property real w
        property real len
        property color col
        anchors.centerIn: parent
        rotation: angle
        Behavior on rotation { enabled: f.live; RotationAnimation { duration: Theme.ms(400); direction: RotationAnimation.Clockwise; easing.type: Easing.OutCubic } }
        Rectangle { width: parent.w; height: parent.len; radius: width / 2; color: parent.col; anchors.horizontalCenter: parent.horizontalCenter; anchors.bottom: parent.top; anchors.bottomMargin: -width / 2 }
    }
    Hand { angle: (f.now.getHours() % 12) * 30 + f.now.getMinutes() * 0.5; w: f.d * 0.076; len: f.d * 0.24; col: f.hourC }
    Hand { angle: f.now.getMinutes() * 6 + f.now.getSeconds() * 0.1; w: f.d * 0.082; len: f.d * 0.36; col: f.minC }
    // the second: head and tail angles; the head moves first, the tail 100 ms later
    property real head: 0
    property real tail: 0
    property int lastSec: -1
    function step() {
        const sec = f.now.getSeconds();
        if (sec === lastSec) return;
        const first = lastSec < 0;
        lastSec = sec;
        const target = sec * 6;
        const from = ((tail % 360) + 360) % 360;
        const diff = (target - from + 360) % 360;
        morph.stop();
        if (first || !f.live || diff === 0 || diff > 12) { head = target; tail = target; return; }
        headAnim.from = from; headAnim.to = from + diff;
        tailAnim.from = from; tailAnim.to = from + diff;
        morph.start();
    }
    Connections { target: f; function onNowChanged() { f.step(); } }
    Component.onCompleted: step()
    ParallelAnimation {
        id: morph
        NumberAnimation { id: headAnim; target: f; property: "head"; duration: 250; easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: 100 }
            NumberAnimation { id: tailAnim; target: f; property: "tail"; duration: 250; easing.type: Easing.OutCubic }
        }
    }
    Shape {
        id: secShape
        visible: f.secs
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real dot: f.d * 0.0425
        readonly property real rad: f.d / 2 - (f.height * 0.075 + dot)
        ShapePath {
            strokeColor: f.secC
            strokeWidth: secShape.dot * 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: f.width / 2; centerY: f.height / 2
                radiusX: Math.max(1, secShape.rad); radiusY: radiusX
                startAngle: f.tail - 90
                sweepAngle: Math.max(0.05, f.head - f.tail)
            }
        }
    }
    Rectangle { anchors.centerIn: parent; width: f.d * 0.03; height: width; radius: width / 2; color: f.dial }
}
