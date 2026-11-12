import QtQuick
import "../core"

// Touch feedback: a state layer (hover 8%, press 12%) and an ink ripple from the press point,
// clipped to the control's rounded shape. Call press(x, y) / release() from a MouseArea.
Item {
    id: ripple
    anchors.fill: parent
    z: 50
    property real radius: 0
    property color ink: Theme.text
    property bool hovered: false
    property bool pressed: false

    Rectangle {
        anchors.fill: parent
        radius: ripple.radius
        color: ripple.ink
        opacity: ripple.pressed ? 0.12 : (ripple.hovered ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: Theme.ms(150); easing.type: Easing.OutCubic } }
    }

    property real cx: width / 2
    property real cy: height / 2
    property real spread: 0
    property real alpha: 0
    readonly property real reach: Math.sqrt(Math.pow(Math.max(cx, width - cx), 2) + Math.pow(Math.max(cy, height - cy), 2)) + 6

    function press(x, y) {
        cx = x; cy = y;
        fade.stop(); grow.stop();
        spread = 0; alpha = 0.16;
        grow.start();
    }
    function release() { fade.restart(); }
    // (never left glowing: when the press ends however it ends, the ink fades)
    onPressedChanged: if (!pressed && alpha > 0 && !fade.running) release()

    NumberAnimation {
        id: grow; target: ripple; property: "spread"; from: 0; to: ripple.reach; duration: Theme.ms(420)
        easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve
    }
    SequentialAnimation {
        id: fade
        PauseAnimation { duration: grow.running ? Theme.ms(120) : 0 }
        NumberAnimation { target: ripple; property: "alpha"; to: 0; duration: Theme.ms(300); easing.type: Easing.OutCubic }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: ripple.alpha > 0.001
        property vector2d itemSize: Qt.vector2d(width, height)
        property real shapeRadius: ripple.radius
        property vector2d center: Qt.vector2d(ripple.cx, ripple.cy)
        property real rippleRadius: ripple.spread
        property color inkColor: ripple.ink
        property real inkAlpha: ripple.alpha
        fragmentShader: Qt.resolvedUrl("shaders/ripple.frag.qsb")
    }
}
