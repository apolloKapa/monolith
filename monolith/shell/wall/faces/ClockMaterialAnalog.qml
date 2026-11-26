import QtQuick
import QtQuick.Shapes
import "../../core"
import "../../ui"

// Material analog: a dial with twelve gentle scallops in the primary container colour, two thick
// rounded hands (hours, minutes), and the seconds as a dot riding near the rim. Each second the
// dot runs on to the next position as a short streak, its front first and its back a moment
// later, so it stretches and then gathers up again.
FaceBase {
    id: face
    readonly property real side: Math.min(width, height)
    readonly property color dialInk: Theme.m("primary_container", Theme.accentContainer)
    readonly property color hourInk: face.hasMain ? face.mainC : Theme.m("secondary", Theme.subtext)
    readonly property color minuteInk: face.hasAccent ? face.accentC : Theme.m("primary", Theme.accent)
    readonly property color secondInk: face.hasAccent ? face.accentC : Theme.m("tertiary", Theme.accent)

    LobeDial {
        width: face.side
        height: face.side
        anchors.centerIn: parent
        steps: 240
        fill: face.dialInk
        // twelve scallops: 1.2 % of the dial in and out round a radius of 46 %
        radiusAt: deg => width * 0.46 + width * 0.012 * Math.cos(12 * deg * Math.PI / 180)
    }

    // a hand: a rounded bar standing on the middle (its round end over the pivot), turned to `deg`
    component Arm: Item {
        id: arm
        property real deg
        property real thick
        property real reach
        property color ink
        anchors.centerIn: parent
        rotation: deg
        Behavior on rotation { enabled: face.live; RotationAnimation { duration: Theme.ms(400); direction: RotationAnimation.Clockwise; easing.type: Easing.OutCubic } }
        Rectangle {
            width: arm.thick
            height: arm.reach
            radius: width / 2
            color: arm.ink
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.top
            anchors.bottomMargin: -width / 2
        }
    }
    Arm { deg: (face.now.getHours() % 12) * 30 + face.now.getMinutes() / 2; thick: face.side * 0.076; reach: face.side * 0.24; ink: face.hourInk }
    Arm { deg: face.now.getMinutes() * 6 + face.now.getSeconds() / 10; thick: face.side * 0.082; reach: face.side * 0.36; ink: face.minuteInk }

    // the seconds streak: where its front and back are (degrees, growing; 0 = twelve)
    property real front: 0
    property real back: 0
    property int seen: -1
    onNowChanged: advance()
    Component.onCompleted: advance()
    function advance() {
        const s = face.now.getSeconds();
        if (s === seen) return;
        const firstTime = seen < 0;
        seen = s;
        const goal = s * 6;
        const start = ((back % 360) + 360) % 360;
        const ahead = (goal - start + 360) % 360;
        streak.stop();
        // a jump (the first look, not live, or more than two seconds on): straight there
        if (firstTime || !face.live || ahead === 0 || ahead > 12) { front = goal; back = goal; return; }
        frontRun.from = start; frontRun.to = start + ahead;
        backRun.from = start; backRun.to = start + ahead;
        streak.start();
    }
    ParallelAnimation {
        id: streak
        NumberAnimation { id: frontRun; target: face; property: "front"; duration: Theme.ms(250); easing.type: Easing.OutCubic }
        SequentialAnimation {
            PauseAnimation { duration: Theme.ms(100) }
            NumberAnimation { id: backRun; target: face; property: "back"; duration: Theme.ms(250); easing.type: Easing.OutCubic }
        }
    }
    Shape {
        id: ticker
        visible: face.opt("showSeconds", true)
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        readonly property real dotR: face.side * 0.0425
        readonly property real orbit: face.side / 2 - face.height * 0.075 - dotR
        ShapePath {
            strokeColor: face.secondInk
            strokeWidth: ticker.dotR * 2
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathAngleArc {
                centerX: face.width / 2
                centerY: face.height / 2
                radiusX: Math.max(1, ticker.orbit)
                radiusY: radiusX
                startAngle: face.back - 90
                sweepAngle: Math.max(0.05, face.front - face.back)
            }
        }
    }
    // the pivot, cut out in the dial's colour
    Rectangle { width: face.side * 0.03; height: width; radius: width / 2; color: face.dialInk; anchors.centerIn: parent }
}
