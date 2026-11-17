import QtQuick
import QtQuick.Effects
import QtQuick.Shapes
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Shutting down, restarting, logging out, going to sleep (core/Power.qml): the screen, as it was,
// eases back and blurs and darkens; a card rises in, piece by piece: a ring (an accent arc that
// grows and shrinks as it spins, a faint one turning the other way) round the action's icon with a
// soft glow breathing behind it, then what's happening, then a word or two. As the action runs,
// everything fades to black. It takes every click and key, and stays until the session ends.
PanelWindow {
    id: win
    required property var modelData
    screen: modelData
    WlrLayershell.namespace: "monolith-goodbye"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
    exclusionMode: ExclusionMode.Ignore
    anchors { top: true; bottom: true; left: true; right: true }
    color: "transparent"
    visible: Power.shotsReady

    readonly property var words: ({
        poweroff: ["power_settings_new", "Shutting down", "See you soon"],
        reboot: ["restart_alt", "Restarting", "Back in a moment"],
        logout: ["logout", "Logging out", "Closing everything"],
        suspend: ["bedtime", "Going to sleep", "Good night"],
    })
    readonly property var w: words[Power.going] || words.poweroff
    readonly property bool anim: Theme.animOn

    // the background: 0 → 1 as it blurs in; the card's pieces follow, a little later each
    property real t: 0
    property real card: 0
    NumberAnimation on t { from: 0; to: 1; duration: Math.max(1, Theme.ms(700)); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve; running: win.visible }
    NumberAnimation on card { from: 0; to: 1; duration: Math.max(1, Theme.ms(900)); easing.type: Easing.Linear; running: win.visible }
    // each piece's own 0 → 1, starting `at` of the way into `card`, eased
    function piece(at) {
        const x = Math.max(0, Math.min(1, (card - at) / 0.55));
        return 1 - Math.pow(1 - x, 3);
    }

    // the screen as it was, blurred. Drawn 80 px past every edge of the screen: blurring near an
    // edge pulls in what's past it, and past a picture's edge there's nothing, which darkened every
    // border. (The picture is stretched that little bit; under the blur it doesn't show)
    Image {
        id: shot
        source: Power.shotsReady ? "file://" + Power.shotFor(win.modelData.name) + "?" + Power.shotsTaken : ""
        cache: false
        visible: false
        x: -80; y: -80
        width: win.width + 160; height: win.height + 160
        fillMode: Image.Stretch
    }
    MultiEffect {
        x: -80; y: -80
        width: win.width + 160; height: win.height + 160
        source: shot
        visible: shot.status === Image.Ready
        autoPaddingEnabled: false
        blurEnabled: true
        blur: win.t
        blurMax: 64
        blurMultiplier: 0.6
        brightness: -0.22 * win.t
        saturation: -0.3 * win.t
        // easing back, just a little: depth
        scale: 1 - 0.03 * win.t
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: (shot.status === Image.Ready ? 0.22 : 0.7) * win.t
    }
    // what's happening
    Item {
        id: cardBox
        anchors.centerIn: parent
        width: 360; height: col.implicitHeight
        Column {
            id: col
            width: parent.width
            spacing: 20

            Item {
                id: badge
                anchors.horizontalCenter: parent.horizontalCenter
                width: 128; height: 128
                readonly property real p: win.piece(0)
                opacity: p
                scale: 0.6 + 0.4 * p
                transform: Translate { y: (1 - badge.p) * 24 }

                // the glow, breathing
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * 1.6; height: width
                    radius: Theme.rnd(width / 2)
                    color: Theme.accent
                    opacity: 0.0
                    layer.enabled: true
                    layer.effect: MultiEffect { blurEnabled: true; blur: 1; blurMax: 48 }
                    SequentialAnimation on opacity {
                        running: win.visible && win.anim
                        loops: Animation.Infinite
                        NumberAnimation { from: 0.10; to: 0.26; duration: 1400; easing.type: Easing.InOutSine }
                        NumberAnimation { from: 0.26; to: 0.10; duration: 1400; easing.type: Easing.InOutSine }
                    }
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: 10
                    radius: (Theme.chamfer || Theme.square) ? 0 : width / 2
                    color: Qt.alpha(Theme.frame, 0.78)
                    border.width: 1
                    border.color: Qt.alpha(Theme.text, 0.1)
                }
                // the faint ring, turning backwards
                Shape {
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    RotationAnimator on rotation { from: 360; to: 0; duration: 5200; loops: Animation.Infinite; running: win.visible && win.anim }
                    ShapePath {
                        strokeColor: Qt.alpha(Theme.text, 0.16)
                        strokeWidth: 2
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 64; centerY: 64; radiusX: 61; radiusY: 61; startAngle: 0; sweepAngle: 300 }
                    }
                }
                // the accent arc: spinning, growing and shrinking
                Shape {
                    id: arc
                    anchors.fill: parent
                    preferredRendererType: Shape.CurveRenderer
                    property real sweep: 60
                    RotationAnimator on rotation { from: 0; to: 360; duration: 1300; loops: Animation.Infinite; running: win.visible && win.anim }
                    SequentialAnimation on sweep {
                        running: win.visible && win.anim
                        loops: Animation.Infinite
                        NumberAnimation { from: 40; to: 250; duration: 750; easing.type: Easing.InOutCubic }
                        NumberAnimation { from: 250; to: 40; duration: 750; easing.type: Easing.InOutCubic }
                    }
                    ShapePath {
                        strokeColor: Theme.accent
                        strokeWidth: 4
                        fillColor: "transparent"
                        capStyle: ShapePath.RoundCap
                        PathAngleArc { centerX: 64; centerY: 64; radiusX: 55; radiusY: 55; startAngle: -90; sweepAngle: arc.sweep }
                    }
                }
                Icon {
                    anchors.centerIn: parent
                    name: win.w[0]
                    size: 44
                    color: Theme.text
                }
            }
            Label {
                id: title
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real p: win.piece(0.18)
                opacity: p
                transform: Translate { y: (1 - title.p) * 16 }
                text: win.w[1]
                strong: true
                font.pixelSize: 30
                font.letterSpacing: 0.5
                color: "#ffffff"
                // the dots after it, one after another
                Label {
                    anchors.left: parent.right
                    anchors.baseline: parent.baseline
                    property int n: 3
                    text: ".".repeat(n) + " ".repeat(3 - n)
                    strong: true
                    font.pixelSize: 30
                    color: "#ffffff"
                    Timer { interval: 420; repeat: true; running: win.visible && win.anim; onTriggered: parent.n = (parent.n + 1) % 4 }
                }
            }
            Label {
                id: sub
                anchors.horizontalCenter: parent.horizontalCenter
                readonly property real p: win.piece(0.32)
                opacity: 0.72 * p
                transform: Translate { y: (1 - sub.p) * 12 }
                text: win.w[2]
                font.pixelSize: Theme.sizeSmall + 2
                color: "#ffffff"
            }
        }
    }

    // as the action runs: everything goes to black
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        opacity: Power.closing ? 1 : 0
        Behavior on opacity { NumberAnimation { duration: Math.max(1, Theme.ms(420)); easing.type: Easing.InCubic } }
    }

    // nothing gets through while it's on
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }
    Item { focus: true; Keys.onPressed: e => e.accepted = true }
}
