import QtQuick
import QtQuick.Window
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../"
import "../reusables"

// Monolith's first-launch intro. A line of light draws across the dark, rises into the
// monolith (a tall rounded slab in the wallpaper's colours) while soft colour glows open up
// behind it; the slab settles, "Monolith" draws together under it, then a Get started button.
PanelWindow {
    id: window

    signal finished()
    signal closed()

    WlrLayershell.namespace: "welcome-guide"
    WlrLayershell.layer: WlrLayer.Overlay
    WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive

    exclusionMode: ExclusionMode.Ignore
    focusable: true
    screen: Quickshell.primaryScreen || null

    implicitWidth: screen ? screen.width : 1920
    implicitHeight: screen ? screen.height : 1080
    color: "transparent"

    function s(val) {
        let res = Scaler.s(val);
        return res > 0 ? res : val;
    }

    readonly property color accent: ThemeBackend.mauve || "#cba6f7"
    readonly property color accent2: ThemeBackend.blue || "#89b4fa"
    readonly property color accent3: ThemeBackend.peach || "#fab387"

    // the steps of the intro, each 0 -> 1
    property real dim: 0          // the screen going dark
    property real line: 0         // the line of light drawing out
    property real rise: 0         // the line rising into the slab
    property real glow: 0         // colour glows behind
    property real settle: 0       // the slab moving up and shrinking
    property real word: 0         // "Monolith" drawing together
    property real tagline: 0      // the line under it
    property real button: 0       // Get started
    property real leave: 0        // closing

    property bool ready: false

    Timer {
        interval: 200
        running: true
        onTriggered: intro.start()
    }

    SequentialAnimation {
        id: intro
        NumberAnimation { target: window; property: "dim"; to: 1; duration: (500) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
        NumberAnimation { target: window; property: "line"; to: 1; duration: (700) * ThemeBackend.animScale; easing.type: Easing.InOutCubic }
        ParallelAnimation {
            NumberAnimation { target: window; property: "rise"; to: 1; duration: (1000) * ThemeBackend.animScale; easing.type: Easing.OutBack; easing.overshoot: 1.1 }
            NumberAnimation { target: window; property: "glow"; to: 1; duration: (1800) * ThemeBackend.animScale; easing.type: Easing.OutSine }
        }
        PauseAnimation { duration: (350) * ThemeBackend.animScale }
        ParallelAnimation {
            NumberAnimation { target: window; property: "settle"; to: 1; duration: (900) * ThemeBackend.animScale; easing.type: Easing.InOutCubic }
            SequentialAnimation {
                PauseAnimation { duration: (300) * ThemeBackend.animScale }
                NumberAnimation { target: window; property: "word"; to: 1; duration: (1100) * ThemeBackend.animScale; easing.type: Easing.OutQuint }
            }
        }
        NumberAnimation { target: window; property: "tagline"; to: 1; duration: (700) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
        PauseAnimation { duration: (250) * ThemeBackend.animScale }
        NumberAnimation { target: window; property: "button"; to: 1; duration: (600) * ThemeBackend.animScale; easing.type: Easing.OutCubic }
        ScriptAction { script: window.ready = true }
    }

    function begin() {
        if (!window.ready || closeSequence.running) return;
        closeSequence.start();
    }

    SequentialAnimation {
        id: closeSequence
        NumberAnimation { target: window; property: "leave"; to: 1; duration: (700) * ThemeBackend.animScale; easing.type: Easing.InOutCubic }
        ScriptAction {
            script: {
                // one signal: FirstLaunch opens Settings on it (finished and closed both did)
                window.finished();
                window.visible = false;
            }
        }
    }

    Item {
        id: stage
        anchors.fill: parent
        focus: true
        opacity: 1 - window.leave
        Keys.onReturnPressed: window.begin()
        Keys.onEnterPressed: window.begin()
        Keys.onSpacePressed: window.begin()

        Rectangle {
            anchors.fill: parent
            color: ThemeBackend.crust
            opacity: window.dim
        }

        // soft glows in the theme's colours, drifting slowly
        Item {
            id: glows
            anchors.fill: parent
            opacity: window.glow * 0.5

            property real t: 0
            NumberAnimation on t { from: 0; to: Math.PI * 2; duration: 26000; loops: Animation.Infinite; running: window.visible }

            Repeater {
                model: [
                    { c: window.accent,  x: 0.38, y: 0.42, r: 0.30, dx: 0.06, dy: 0.04, p: 0.0 },
                    { c: window.accent2, x: 0.62, y: 0.55, r: 0.26, dx: 0.05, dy: 0.06, p: 2.1 },
                    { c: window.accent3, x: 0.50, y: 0.72, r: 0.18, dx: 0.07, dy: 0.03, p: 4.2 }
                ]
                // a radial glow: full colour in the middle, fading to nothing at the edge
                Canvas {
                    required property var modelData
                    // fixed size (repainting a canvas every frame is costly); it grows by scale
                    width: Math.min(glows.width, glows.height) * modelData.r * 2.6
                    height: width
                    scale: 0.6 + 0.4 * window.glow
                    renderTarget: Canvas.FramebufferObject
                    onWidthChanged: requestPaint()
                    onPaint: {
                        const ctx = getContext("2d");
                        ctx.reset();
                        const g = ctx.createRadialGradient(width / 2, height / 2, 0, width / 2, height / 2, width / 2);
                        const c = modelData.c;
                        g.addColorStop(0.0, Qt.rgba(c.r, c.g, c.b, 0.9));
                        g.addColorStop(0.45, Qt.rgba(c.r, c.g, c.b, 0.35));
                        g.addColorStop(1.0, Qt.rgba(c.r, c.g, c.b, 0.0));
                        ctx.fillStyle = g;
                        ctx.fillRect(0, 0, width, height);
                    }
                    x: glows.width * (modelData.x + modelData.dx * Math.sin(glows.t + modelData.p)) - width / 2
                    y: glows.height * (modelData.y + modelData.dy * Math.cos(glows.t * 0.8 + modelData.p)) - height / 2
                }
            }
        }

        // the monolith: a line of light that rises into a slab
        Item {
            id: slabHolder
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 - window.s(150) * window.settle
            scale: 1 - 0.45 * window.settle

            readonly property real fullW: window.s(120)
            readonly property real fullH: window.s(300)

            // the line, before it rises
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: -height / 2
                width: slabHolder.fullW * 2.2 * window.line * (1 - window.rise) + slabHolder.fullW * window.rise
                height: Math.max(2, window.s(3))
                radius: height / 2
                opacity: window.line * (1 - window.rise)
                color: ThemeBackend.text
            }

            // the slab
            Rectangle {
                id: slab
                anchors.horizontalCenter: parent.horizontalCenter
                width: slabHolder.fullW
                height: Math.max(2, slabHolder.fullH * window.rise)
                y: -height / 2
                radius: ThemeBackend.square ? 0 : window.s(28)
                opacity: window.rise > 0 ? 1 : 0
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.lighter(window.accent, 1.15) }
                    GradientStop { position: 0.55; color: window.accent }
                    GradientStop { position: 1.0; color: window.accent2 }
                }
                // a light running down its face
                Rectangle {
                    anchors.horizontalCenter: parent.horizontalCenter
                    y: parent.height * 0.08
                    width: parent.width * 0.62
                    height: window.s(3)
                    radius: height / 2
                    color: Qt.alpha("#ffffff", 0.55)
                    opacity: window.rise
                }
            }

            // its shadow on the "ground"
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                y: slab.height / 2 + window.s(18)
                width: slabHolder.fullW * 1.6 * window.rise
                height: window.s(10)
                radius: height / 2
                color: Qt.alpha("#000000", 0.45)
                opacity: window.rise
                layer.enabled: true
                layer.effect: MultiEffect { blurEnabled: true; blurMax: 24; blur: 1.0 }
            }
        }

        // the name, letters drawing together
        Row {
            id: nameRow
            anchors.horizontalCenter: parent.horizontalCenter
            y: parent.height / 2 + window.s(20)
            spacing: window.s(40) * (1 - window.word)
            opacity: window.word
            Repeater {
                model: "Monolith".split("")
                Text {
                    required property string modelData
                    required property int index
                    text: modelData
                    font.family: ThemeBackend.fontFamily
                    font.pixelSize: window.s(64)
                    font.weight: Font.Normal
                    color: ThemeBackend.text
                    // each letter lands a little after the last
                    readonly property real own: Math.max(0, Math.min(1, window.word * 1.6 - index * 0.08))
                    opacity: own
                    transform: Translate { y: window.s(18) * (1 - own) }
                }
            }
        }

        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: nameRow.bottom
            anchors.topMargin: window.s(10)
            spacing: window.s(6)
            opacity: window.tagline
            transform: Translate { y: window.s(10) * (1 - window.tagline) }

            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("start.tagline", "A desktop for niri")
                font.family: ThemeBackend.fontFamily
                font.pixelSize: window.s(18)
                color: ThemeBackend.subtext0
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: I18n.t("start.made_by", { "author": "apolloKapa" })
                font.family: ThemeBackend.fontFamily
                font.pixelSize: window.s(13)
                color: Qt.alpha(ThemeBackend.subtext0, 0.7)
            }
        }

        // Get started
        Rectangle {
            id: startBtn
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: nameRow.bottom
            anchors.topMargin: window.s(110)
            width: btnLabel.implicitWidth + window.s(56)
            height: window.s(52)
            radius: ThemeBackend.square ? 0 : height / 2
            color: btnMa.pressed ? Qt.darker(window.accent, 1.1) : (btnMa.containsMouse ? Qt.lighter(window.accent, 1.08) : window.accent)
            opacity: window.button
            scale: btnMa.pressed ? 0.97 : 1.0
            transform: Translate { y: window.s(14) * (1 - window.button) }
            Behavior on scale { NumberAnimation { duration: (120) * ThemeBackend.animScale } }

            Text {
                id: btnLabel
                anchors.centerIn: parent
                text: I18n.t("start.get_started", "Get started")
                font.family: ThemeBackend.fontFamily
                font.weight: Font.Medium
                font.pixelSize: window.s(17)
                color: ThemeBackend.onPrimary
            }
            MouseArea {
                id: btnMa
                anchors.fill: parent
                hoverEnabled: true
                enabled: window.ready
                cursorShape: Qt.PointingHandCursor
                onClicked: window.begin()
            }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.top: startBtn.bottom
            anchors.topMargin: window.s(12)
            opacity: window.button * 0.6
            text: I18n.t("start.press_enter", "or press Enter")
            font.family: ThemeBackend.fontFamily
            font.pixelSize: window.s(12)
            color: ThemeBackend.subtext0
        }
    }
}
