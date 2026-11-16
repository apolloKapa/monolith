import QtQuick
import QtQuick.Shapes
import "../../core"
import "../../ui"

// Cyberpunk: a HUD readout. A dark panel with two corners cut and a neon edge, a yellow label
// block (LOCAL TIME), the hours and minutes as big as fit with a red and a cyan ghost a little to
// either side (a split signal) and the seconds small after them, the day and date under them, and
// the minute's seconds again as a row of segments filling up. Now and then (every 10-20 s, if Glitch is
// on) the time slips sideways for a moment: a small, short jolt, never a flash.
FaceBase {
    id: f
    clip: false
    readonly property color neon: f.hasMain ? f.mainC : Theme.c("yellow", "#fcee0a")
    readonly property color edge: f.hasAccent ? f.accentC : Theme.c("teal", "#00f0ff")
    readonly property color hot: Theme.c("pink", "#ff2a6d")
    readonly property string fam: f.fontOr(Qt.fontFamilies().indexOf("Rajdhani") !== -1 ? "Rajdhani" : Theme.fontFamily)
    readonly property bool framed: f.opt("frame", true) !== false
    readonly property bool glitches: f.opt("glitch", true) !== false
    readonly property bool h12: f.opt("hour12", false) === true
    readonly property real u: Math.min(width / 3.2, height)          // a unit that keeps it in proportion
    readonly property real cut: u * 0.12
    readonly property int sec: f.now.getSeconds()

    // the jolt: 0 at rest; up and back down in a quarter of a second
    property real jolt: 0
    property real joltDir: 1
    Timer {
        id: nextJolt
        running: f.live && f.glitches && Theme.animOn
        interval: 10000 + Math.random() * 10000
        onTriggered: { f.joltDir = Math.random() < 0.5 ? -1 : 1; joltAnim.restart(); interval = 10000 + Math.random() * 10000; }
    }
    SequentialAnimation {
        id: joltAnim
        NumberAnimation { target: f; property: "jolt"; to: 1; duration: Theme.fxMs(60); easing.type: Easing.OutQuad }
        PauseAnimation { duration: Theme.fxMs(70) }
        NumberAnimation { target: f; property: "jolt"; to: 0.4; duration: Theme.fxMs(40) }
        NumberAnimation { target: f; property: "jolt"; to: 0; duration: Theme.fxMs(110); easing.type: Easing.OutCubic }
    }

    // ── the panel ──
    Shape {
        anchors.fill: parent
        visible: f.framed
        preferredRendererType: Shape.CurveRenderer
        ShapePath {
            fillColor: Qt.rgba(0.02, 0.02, 0.05, 0.62)
            strokeColor: Qt.alpha(f.edge, 0.85)
            strokeWidth: Math.max(1, f.u * 0.012)
            joinStyle: ShapePath.MiterJoin
            // top-left and bottom-right cut across
            startX: f.cut; startY: 0
            PathLine { x: f.width; y: 0 }
            PathLine { x: f.width; y: f.height - f.cut }
            PathLine { x: f.width - f.cut; y: f.height }
            PathLine { x: 0; y: f.height }
            PathLine { x: 0; y: f.cut }
            PathLine { x: f.cut; y: 0 }
        }
    }
    // a tick of yellow along the top and a bracket at the bottom left, like the style's panels
    Rectangle { visible: f.framed; x: f.width * 0.62; y: 0; width: f.u * 0.32; height: Math.max(2, f.u * 0.02); color: f.neon }
    Rectangle { visible: f.framed; x: 0; y: f.height - height; width: f.u * 0.18; height: Math.max(2, f.u * 0.02); color: f.edge }
    Rectangle { visible: f.framed; x: 0; y: f.height - f.u * 0.22; width: Math.max(2, f.u * 0.02); height: f.u * 0.22; color: f.edge }

    Item {
        id: body
        anchors.fill: parent
        anchors.leftMargin: f.cut + f.u * 0.04; anchors.rightMargin: f.u * 0.1
        anchors.topMargin: f.u * 0.08; anchors.bottomMargin: f.u * 0.09

        // the label block and the seconds
        Row {
            id: head
            spacing: f.u * 0.05
            Rectangle {
                width: lbl.implicitWidth + f.u * 0.1; height: f.u * 0.15
                color: f.neon
                Text { renderType: Text.CurveRendering;
                    id: lbl
                    anchors.centerIn: parent
                    text: "LOCAL TIME"
                    color: "#0a0a0f"
                    font.family: f.fam; font.pixelSize: f.u * 0.1; font.weight: Font.Bold; font.letterSpacing: f.u * 0.01
                }
            }
            Text { renderType: Text.CurveRendering;
                anchors.verticalCenter: parent.verticalCenter
                text: f.h12 ? Qt.formatTime(f.now, "AP") : "SYNC OK"
                color: Qt.alpha(f.edge, 0.9)
                font.family: f.fam; font.pixelSize: f.u * 0.1; font.weight: Font.DemiBold; font.letterSpacing: f.u * 0.012
            }
        }

        // the time: a red and a cyan ghost under it, split a little to either side
        Item {
            id: timeBox
            anchors.top: head.bottom; anchors.topMargin: f.u * 0.02
            anchors.left: parent.left; anchors.right: parent.right
            anchors.bottom: dateRow.top; anchors.bottomMargin: f.u * 0.02
            readonly property string t: Qt.formatTime(f.now, f.h12 ? "hh:mm" : "HH:mm")
            readonly property string s: String(f.sec).padStart(2, "0")
            readonly property real split: Math.max(1.5, f.u * 0.012) + f.jolt * f.u * 0.04
            readonly property real shift: f.jolt * f.joltDir * f.u * 0.05
            // as big as fits: the digits' ink as tall as the box, or the time and its seconds as
            // wide as it (measured at 100 px)
            TextMetrics { id: big; font.family: f.fam; font.weight: Font.Bold; font.pixelSize: 100; text: "88:88" }
            TextMetrics { id: small; font.family: f.fam; font.weight: Font.Bold; font.pixelSize: 100; text: "88" }
            readonly property real px: Math.max(10, Math.min(height / Math.max(1, big.tightBoundingRect.height) * 92,
                width / Math.max(1, big.advanceWidth + small.advanceWidth * 0.4 + 6) * 96))
            component Digits: Text { renderType: Text.CurveRendering;
                height: timeBox.height
                font.pixelSize: timeBox.px
                font.weight: Font.Bold
                verticalAlignment: Text.AlignVCenter
                text: timeBox.t
                font.family: f.fam
            }
            Digits { x: timeBox.shift - timeBox.split; color: Qt.alpha(f.hot, 0.55) }
            Digits { x: timeBox.shift + timeBox.split; color: Qt.alpha(f.edge, 0.55) }
            Digits {
                id: main; x: timeBox.shift
                text: f.inked(timeBox.t, f.neon, 0); textFormat: f.textFormatFor
                color: f.inkColor(f.neon)
                // Colouring → Gradient: laid over the digits (drawn white)
                layer.enabled: f.gradientOn
                layer.effect: GradientTint { from: f.gradFrom; to: f.gradTo; dir: f.gradVec }
            }
            // the seconds, small, on the time's baseline
            Text { renderType: Text.CurveRendering;
                x: main.x + main.implicitWidth + timeBox.px * 0.06
                anchors.baseline: main.baseline
                text: timeBox.s
                color: Qt.alpha(f.edge, 0.9)
                font.family: f.fam; font.pixelSize: timeBox.px * 0.4; font.weight: Font.Bold
            }
        }

        // the day and date, then the seconds as segments
        Row {
            id: dateRow
            anchors.bottom: segs.top; anchors.bottomMargin: f.u * 0.04
            spacing: f.u * 0.04
            Text { renderType: Text.CurveRendering;
                text: Qt.formatDate(f.now, "ddd").toUpperCase()
                color: f.hot
                font.family: f.fam; font.pixelSize: f.u * 0.11; font.weight: Font.Bold; font.letterSpacing: f.u * 0.015
            }
            Text { renderType: Text.CurveRendering;
                text: "//"
                color: Qt.alpha(f.edge, 0.5)
                font.family: f.fam; font.pixelSize: f.u * 0.11; font.weight: Font.Bold
            }
            Text { renderType: Text.CurveRendering;
                text: Qt.formatDate(f.now, "dd.MM.yyyy")
                color: Qt.alpha(f.edge, 0.95)
                font.family: f.fam; font.pixelSize: f.u * 0.11; font.weight: Font.DemiBold; font.letterSpacing: f.u * 0.015
            }
        }
        Row {
            id: segs
            anchors.bottom: parent.bottom
            anchors.left: parent.left; anchors.right: parent.right
            spacing: Math.max(1, f.u * 0.012)
            readonly property int n: 30
            readonly property int lit: Math.floor(f.sec / 2) + 1
            Repeater {
                model: segs.n
                Rectangle {
                    required property int index
                    width: (segs.width - segs.spacing * (segs.n - 1)) / segs.n
                    height: Math.max(3, f.u * 0.035)
                    color: index < segs.lit ? (index === segs.lit - 1 ? f.neon : f.edge) : Qt.alpha(f.edge, 0.16)
                }
            }
        }
    }
}
