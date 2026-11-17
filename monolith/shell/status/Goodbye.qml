import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import "../core"
import "../ui"

// Shutting down, restarting, logging out, going to sleep (core/Power.qml): the whole screen, as it
// was, blurs and darkens, and a card says what's happening, a ring turning round its icon. It
// takes every click and key (nothing gets started by accident) and stays until the session ends.
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

    // 0 → 1 as it comes in
    property real t: 0
    NumberAnimation on t { from: 0; to: 1; duration: Math.max(1, Theme.ms(520)); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve; running: win.visible }

    // the screen as it was, blurred (a picture taken the moment the button was pressed)
    Image {
        id: shot
        anchors.fill: parent
        source: Power.shotsReady ? "file://" + Power.shotFor(win.modelData.name) + "?" + Power.shotsTaken : ""
        cache: false
        visible: false
        fillMode: Image.Stretch
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
        blurEnabled: true
        blur: win.t
        blurMax: 64
        brightness: -0.18 * win.t
        saturation: -0.25 * win.t
    }
    Rectangle {
        anchors.fill: parent
        color: "#000000"
        // (no picture: just darker)
        opacity: (shot.status === Image.Ready ? 0.28 : 0.72) * win.t
    }

    // what's happening
    Column {
        anchors.centerIn: parent
        spacing: 18
        opacity: win.t
        scale: 0.92 + 0.08 * win.t
        Item {
            anchors.horizontalCenter: parent.horizontalCenter
            width: 112; height: 112
            Rectangle { anchors.fill: parent; radius: Theme.chamfer ? 0 : width / 2; color: Qt.alpha(Theme.frame, 0.72); border.width: 1; border.color: Qt.alpha(Theme.text, 0.12) }
            // the ring: an arc turning round the icon
            Canvas {
                id: ring
                anchors.fill: parent
                anchors.margins: 6
                antialiasing: true
                property color c: Theme.accent
                onCChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.lineWidth = 4;
                    ctx.lineCap = "round";
                    ctx.strokeStyle = Qt.alpha(ring.c, 0.18);
                    ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - 3, 0, Math.PI * 2); ctx.stroke();
                    ctx.strokeStyle = ring.c;
                    ctx.beginPath(); ctx.arc(width / 2, height / 2, width / 2 - 3, -Math.PI / 2, Math.PI * 0.35); ctx.stroke();
                }
                RotationAnimator on rotation { from: 0; to: 360; duration: 1100; loops: Animation.Infinite; running: win.visible }
            }
            Icon {
                anchors.centerIn: parent
                name: win.w[0]
                size: 44
                color: Theme.text
                // a slow breath
                SequentialAnimation on opacity {
                    running: win.visible && Theme.animOn
                    loops: Animation.Infinite
                    NumberAnimation { from: 1; to: 0.55; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 0.55; to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.w[1] + "…"
            strong: true
            font.pixelSize: 30
            color: "#ffffff"
        }
        Label {
            anchors.horizontalCenter: parent.horizontalCenter
            text: win.w[2]
            font.pixelSize: Theme.sizeSmall + 2
            color: Qt.alpha("#ffffff", 0.7)
        }
    }

    // nothing gets through while it's on
    MouseArea { anchors.fill: parent; acceptedButtons: Qt.AllButtons; hoverEnabled: true }
    Item { focus: true; Keys.onPressed: e => e.accepted = true }
}
