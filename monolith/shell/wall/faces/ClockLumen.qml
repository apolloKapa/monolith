import QtQuick
import "../../core"
import "../../ui"

// Lumen: a raised, softly lit disc with a lobe towards every hour. As a hand comes near an hour
// its lobe swells, a halo opens behind that hour's number and the number lights up in the hand's
// colour; they settle back as the hand moves on. The second hand sweeps smoothly.
FaceBase {
    id: face
    readonly property real side: Math.min(width, height)
    readonly property bool seconds: opt("showSeconds", true)
    readonly property color dialInk: Theme.m("primary_container", Theme.accentContainer)
    readonly property color hourInk: face.hasMain ? face.mainC : Theme.m("secondary", Theme.subtext)
    readonly property color minuteInk: face.hasAccent ? face.accentC : Theme.m("primary", Theme.accent)
    readonly property color secondInk: face.hasAccent ? face.accentC : Theme.m("tertiary", Theme.accent)
    readonly property color figureInk: face.hasMain ? face.mainC : Theme.m("on_primary_container", Theme.text)

    // the hands' angles (degrees from twelve, clockwise); the seconds include milliseconds
    property real hourDeg: 0
    property real minuteDeg: 0
    property real secondDeg: 0
    // how lit each hour is (0–1): whichever hand is nearest it counts
    property var lit: [0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0]

    // light from a hand at `hand` on the mark at `mark`: full on it, nothing `reach` degrees off,
    // easing out like the square of a cosine in between
    function lightOf(hand, mark, reach) {
        const off = ((hand - mark) % 360 + 360) % 360;
        const gap = Math.min(off, 360 - off);
        return gap >= reach ? 0 : Math.pow(Math.cos(gap / reach * Math.PI / 2), 2);
    }
    // each hand's reach (degrees) and how strongly it lights
    function hourLight(mark) { return lightOf(hourDeg, mark, 45); }
    function minuteLight(mark) { return lightOf(minuteDeg, mark, 40); }
    function secondLight(mark) { return seconds ? lightOf(secondDeg, mark, 32) * 0.85 : 0; }

    function update() {
        const t = new Date();
        const s = t.getSeconds(), m = t.getMinutes();
        hourDeg = (t.getHours() % 12) * 30 + m / 2 + s / 120;
        minuteDeg = m * 6 + s / 10;
        secondDeg = (s + t.getMilliseconds() / 1000) * 6;
        lit = lit.map((_, k) => Math.max(hourLight(k * 30), minuteLight(k * 30), secondLight(k * 30)));
    }
    Component.onCompleted: update()
    // sweeping: 30 updates a second (smooth to the eye, and not every frame of a 165 Hz screen);
    // without the second hand, once a second
    Timer { interval: face.seconds ? 33 : 1000; repeat: true; running: face.live && face.visible; triggeredOnStart: !face.seconds; onTriggered: face.update() }

    LobeDial {
        id: disc
        anchors.fill: parent
        steps: 360
        readonly property real base: face.side * 0.435
        readonly property real swell: face.side * 0.042
        // a lobe per hour, its height following how lit that hour is (28 % of it always there)
        radiusAt: deg => {
            const hour = Math.round(deg / 30) % 12;
            const off = Math.min(Math.abs(deg - hour * 30), 360 - Math.abs(deg - hour * 30));
            return base + swell * (0.28 + 0.72 * (face.lit[hour] || 0)) * (1 + Math.cos(off / 15 * Math.PI)) / 2;
        }
        // lit from the top left: lighter there, darker at the far edge, a faint light rim
        shade: g => {
            const grad = g.createRadialGradient(width / 2 - face.side * 0.16, height / 2 - face.side * 0.2, 0, width / 2, height / 2, base + swell);
            grad.addColorStop(0, Qt.lighter(face.dialInk, 1.16));
            grad.addColorStop(0.6, face.dialInk);
            grad.addColorStop(1, Qt.darker(face.dialInk, 1.1));
            return grad;
        }
        rimWidth: Math.max(1, face.side * 0.0035)
        rimColor: Qt.rgba(1, 1, 1, 0.12)
        fill: face.dialInk
        // Painting it is the costly part (in software), so with the sweeping second hand it's
        // redrawn at most 30 times a second and only once a lobe has moved visibly.
        property var drawnWith: []
        property bool stale: false
        onPaint: drawnWith = face.lit.slice()
        function moved() {
            if (drawnWith.length !== face.lit.length) return true;
            return face.lit.some((v, i) => Math.abs(v - drawnWith[i]) > 0.012);
        }
        Connections {
            target: face
            function onLitChanged() { if (!face.seconds) disc.redraw(); else if (disc.moved()) disc.stale = true; }
        }
        Timer { interval: 33; repeat: true; running: disc.stale && face.live && face.visible; onTriggered: { disc.stale = false; disc.redraw(); } }
    }
    // the hours: a small dot when unlit, a halo and the number when a hand is near
    Repeater {
        model: 12
        Item {
            id: mark
            required property int index
            readonly property int hour: index + 1
            readonly property real deg: (hour % 12) * 30
            readonly property real fromHour: face.hourLight(deg)
            readonly property real fromMinute: face.minuteLight(deg)
            readonly property real fromSecond: face.secondLight(deg)
            readonly property real glow: Math.max(fromHour, fromMinute, fromSecond)
            readonly property color handInk: fromSecond >= fromHour && fromSecond >= fromMinute ? face.secondInk : (fromMinute >= fromHour ? face.minuteInk : face.hourInk)
            readonly property real out: face.side * (0.382 + 0.028 * glow)
            width: face.side * 0.11
            height: width
            x: face.width / 2 + out * Math.sin(deg * Math.PI / 180) - width / 2
            y: face.height / 2 - out * Math.cos(deg * Math.PI / 180) - height / 2
            Rectangle { width: face.side * (mark.hour % 3 === 0 ? 0.016 : 0.011); height: width; radius: width / 2; antialiasing: true
                        color: face.figureInk; opacity: (1 - mark.glow) * 0.3; anchors.centerIn: parent }
            Rectangle { visible: mark.glow > 0.001; width: mark.width * 0.92; height: width; radius: width / 2
                        color: mark.handInk; opacity: mark.glow * 0.24; anchors.centerIn: parent }
            Text {
                visible: mark.glow > 0.001
                anchors.centerIn: parent
                renderType: Text.CurveRendering
                text: mark.hour
                font.family: face.fontOr(Theme.fontFamily)
                font.pixelSize: face.side * 0.054
                font.weight: Font.Bold
                color: mark.glow > 0.5 ? face.figureInk : mark.handInk
                opacity: mark.glow
            }
        }
    }
    // the hands, all turning about the middle: broad hours, slimmer minutes, a fine second hand
    // that also reaches a little way back past the middle
    component Arm: Item {
        id: arm
        property real deg
        property real reach
        property real thick
        property real backReach: 0
        property color ink
        anchors.centerIn: parent
        rotation: deg
        Rectangle { y: -arm.reach; width: arm.thick; height: arm.reach + arm.backReach; radius: width / 2; color: arm.ink; antialiasing: true
                    anchors.horizontalCenter: parent.horizontalCenter }
    }
    Arm { deg: face.hourDeg; reach: face.side * 0.22; thick: face.side * 0.06; ink: face.hourInk }
    Arm { deg: face.minuteDeg; reach: face.side * 0.32; thick: face.side * 0.042; ink: face.minuteInk }
    Arm { visible: face.seconds; deg: face.secondDeg; reach: face.side * 0.37; thick: Math.max(2, face.side * 0.014); backReach: face.side * 0.07; ink: face.secondInk }
    // the cap over the pivot, with a darker centre
    Rectangle {
        width: face.side * 0.085; height: width; radius: width / 2; antialiasing: true
        color: face.seconds ? face.secondInk : face.minuteInk
        anchors.centerIn: parent
        Rectangle { width: parent.width * 0.4; height: width; radius: width / 2; antialiasing: true; color: Qt.darker(face.dialInk, 1.1); anchors.centerIn: parent }
    }
}
