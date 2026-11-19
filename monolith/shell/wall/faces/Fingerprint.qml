import QtQuick
import "../../core"
import "../../ui"

// The fingerprint reader's finger (core/LockState: fprintd while the screen is locked). Waiting,
// it's a fingerprint, breathing a little; a wrong finger and it shakes, red for a moment; the
// right one and it turns into a white tick, the screen unlocking behind it. With no reader (or
// no finger enrolled) it sits there dimmed. Not locked, a click plays both, to see them.
// Three looks (`look`): normal (a round badge), dot (dot-matrix), cyber (a HUD panel).
FaceBase {
    id: f
    property string look: "normal"
    readonly property string st: LockState.fp                    // off | ready | fail | ok
    readonly property bool there: LockState.fpEnrolled || st !== "off"
    readonly property real side: Math.min(width, height)
    // how far it has turned into the tick (0 the fingerprint … 1 the tick)
    property real okK: st === "ok" ? 1 : 0
    Behavior on okK { NumberAnimation { duration: Theme.animOn ? 460 : 0; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
    // a wrong finger: a shake that dies away, and red while it lasts
    property real shake: 0
    readonly property real shakeX: Math.sin(shake * Math.PI * 7) * side * 0.09 * (1 - shake)
    readonly property bool wrong: st === "fail" || shakeAnim.running
    NumberAnimation { id: shakeAnim; target: f; property: "shake"; from: 0; to: 1; duration: Theme.animOn ? 520 : 0; easing.type: Easing.OutCubic }
    Connections { target: LockState; function onFpFailed() { shakeAnim.restart(); } }
    // waiting for a finger: a slow breath (only while it can be seen and something is listening)
    property real breath: 0
    SequentialAnimation on breath {
        running: f.live && f.st === "ready" && Theme.animOn
        loops: Animation.Infinite
        NumberAnimation { to: 1; duration: 1300; easing.type: Easing.InOutSine }
        NumberAnimation { to: 0; duration: 1300; easing.type: Easing.InOutSine }
    }
    onStChanged: if (st !== "ready") breath = 0
    MouseArea { anchors.fill: parent; enabled: !f.editing && !LockState.locked; onClicked: LockState.fpDemo() }

    // ── Normal: a round badge, the fingerprint on it, a ring breathing out while it waits ──
    Item {
        visible: f.look === "normal"
        anchors.centerIn: parent
        width: f.side; height: f.side
        transform: Translate { x: f.shakeX }
        Rectangle {
            anchors.centerIn: parent
            width: f.side * 0.92; height: width; radius: width / 2
            color: "transparent"
            border.width: Math.max(1.5, f.side * 0.012); border.color: f.wrong ? Theme.danger : f.accentC
            opacity: f.st === "ready" ? 0.5 * (1 - f.breath) : 0
            scale: 0.86 + 0.14 * f.breath
        }
        Rectangle {
            id: badge
            anchors.centerIn: parent
            width: f.side * 0.78; height: width; radius: width / 2
            color: f.okK > 0.5 ? Qt.alpha("#3ecf6e", 0.92) : Qt.alpha(Theme.frame, 0.72)
            Behavior on color { ColorAnimation { duration: Theme.ms(260) } }
            border.width: Math.max(1, f.side * 0.01)
            border.color: f.wrong ? Theme.danger : Qt.alpha(f.mainC, f.okK > 0.5 ? 0 : 0.25)
        }
        Icon {
            anchors.centerIn: parent
            name: "fingerprint"; popOnChange: false
            size: f.side * 0.46
            color: f.wrong ? Theme.danger : f.mainC
            Behavior on color { ColorAnimation { duration: Theme.ms(180) } }
            opacity: (f.there ? 1 : 0.35) * Math.max(0, 1 - f.okK * 1.6)
            scale: 1 - 0.45 * Math.min(1, f.okK)
            rotation: -40 * Math.min(1, f.okK)
        }
        Icon {
            anchors.centerIn: parent
            name: "check"; popOnChange: false
            size: f.side * 0.5
            color: "#ffffff"
            font.variableAxes: ({ "FILL": 0, "wght": 700, "opsz": 48 })
            opacity: Math.max(0, Math.min(1, f.okK * 1.6 - 0.3))
            scale: 0.3 + 0.7 * f.okK
        }
    }

    // ── Dot: a fingerprint in a grid of dots, each dot fading over to its place in the tick ──
    DotCard { id: dots; visible: f.look === "dot"; ctx: f.ctx }
    Canvas {
        id: grid
        visible: f.look === "dot"
        anchors.centerIn: parent
        width: f.side * 0.8; height: width
        transform: Translate { x: f.shakeX }
        readonly property int n: 15
        // is the dot (i across, j down) part of the fingerprint: ridges two dots apart, arched
        // over the top half and running straight down the lower one, inside a finger's outline
        function ridge(i, j) {
            const c = (n - 1) / 2, dx = i - c, dy = j - c * 0.86;
            if (Math.abs(dx) > c * 0.9 || dy > c * 1.12) return false;
            const r = dy <= 0 ? Math.hypot(dx, dy * 1.05) : Math.abs(dx);
            if (r > c * 0.92) return false;
            return Math.round(r) % 2 === 0;
        }
        // … or of the tick
        function tick(i, j) {
            const u = i / (n - 1), v = j / (n - 1);
            const d = (ax, ay, bx, by) => {
                const px = bx - ax, py = by - ay, t = Math.max(0, Math.min(1, ((u - ax) * px + (v - ay) * py) / (px * px + py * py)));
                return Math.hypot(u - ax - px * t, v - ay - py * t);
            };
            return Math.min(d(0.2, 0.54, 0.42, 0.76), d(0.42, 0.76, 0.82, 0.28)) < 0.062;
        }
        readonly property real k: Math.max(0, Math.min(1, f.okK))
        readonly property color ink: f.wrong ? "#ff4d5e" : dots.ink
        readonly property color off: dots.off
        readonly property real glow: f.st === "ready" ? f.breath : 0
        onKChanged: requestPaint()
        onInkChanged: requestPaint()
        onGlowChanged: requestPaint()
        onWidthChanged: requestPaint()
        readonly property bool faint: !f.there
        onFaintChanged: requestPaint()
        onPaint: {
            const g = getContext("2d");
            g.reset();
            const cell = width / n, rad = cell * 0.36;
            for (let j = 0; j < n; j++) for (let i = 0; i < n; i++) {
                const a = ridge(i, j) ? 1 : 0, b = tick(i, j) ? 1 : 0;
                const on = a * (1 - k) + b * k;
                g.beginPath();
                g.arc((i + 0.5) * cell, (j + 0.5) * cell, rad, 0, 2 * Math.PI);
                if (on > 0.02) {
                    // (waiting: a band of brighter dots drifts down it, like a scan)
                    const scan = glow > 0 && k < 0.05 ? 0.25 * Math.max(0, 1 - Math.abs(j / (n - 1) - glow) * 5) : 0;
                    g.fillStyle = k > 0.5 ? "#ffffff" : ink;
                    g.globalAlpha = Math.min(1, (faint ? 0.35 : 0.78 + scan) * on + (k > 0.5 ? 0.2 * on : 0));
                } else {
                    g.fillStyle = off;
                    g.globalAlpha = 1;
                }
                g.fill();
            }
        }
    }

    // ── Cyberpunk: a HUD panel, the print in the neon edge colour with a scan line over it ──
    Loader {
        active: f.look === "cyber"
        anchors.fill: parent
        sourceComponent: CyberCard {
            id: cc
            ctx: f.ctx
            label: f.st === "ok" ? "GRANTED" : (f.wrong ? "DENIED" : "BIOMETRIC")
            Item {
                id: stage
                anchors.fill: parent
                transform: Translate { x: f.shakeX }
                readonly property real s: Math.min(width, height * 0.74)
                Item {
                    id: pad
                    width: stage.s; height: stage.s
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: Math.max(0, (parent.height - stage.s - cc.u * 0.2) / 2)
                    clip: true
                    Icon {
                        anchors.centerIn: parent
                        name: "fingerprint"; popOnChange: false
                        size: stage.s * 0.74
                        color: f.wrong ? cc.hot : cc.edge
                        opacity: (f.there ? 1 : 0.35) * Math.max(0, 1 - f.okK * 1.6)
                        scale: 1 - 0.4 * Math.min(1, f.okK)
                    }
                    Icon {
                        anchors.centerIn: parent
                        name: "check"; popOnChange: false
                        size: stage.s * 0.8
                        color: "#ffffff"
                        font.variableAxes: ({ "FILL": 0, "wght": 700, "opsz": 48 })
                        opacity: Math.max(0, Math.min(1, f.okK * 1.6 - 0.3))
                        scale: 0.3 + 0.7 * f.okK
                    }
                    // the scan line, while it waits
                    Rectangle {
                        visible: f.st === "ready"
                        width: parent.width; height: Math.max(2, cc.line * 2)
                        y: f.breath * (parent.height - height)
                        color: cc.neon
                        Rectangle { anchors.bottom: parent.top; width: parent.width; height: stage.s * 0.14; opacity: 0.25
                            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: cc.neon } } }
                    }
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: pad.bottom; anchors.topMargin: cc.u * 0.03
                    renderType: Text.CurveRendering
                    text: f.st === "ok" ? "ACCESS GRANTED" : (f.wrong ? "ACCESS DENIED" : (f.there ? "SCAN FINGER" : "NO READER"))
                    color: f.st === "ok" ? "#ffffff" : (f.wrong ? cc.hot : cc.dim)
                    font.family: cc.fam; font.weight: Font.Bold; font.letterSpacing: 1.5
                    font.pixelSize: Math.max(8, cc.u * 0.085)
                }
            }
        }
    }
}
