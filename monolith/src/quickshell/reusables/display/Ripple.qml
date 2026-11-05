import QtQuick
import "../../"

// Orbit's touch feedback (Material's ink ripple + state layer), laid over a control:
//   - a flat state layer: the ink colour at 8% while hovered, 12% while pressed
//   - a ripple: a disc that spreads from the press point and fades, clipped to the
//     control's rounded shape
// Controls show it only in the Orbit style; call press(x, y) on mouse press and
// release() on release / cancel.
Item {
    id: ripple
    anchors.fill: parent

    property real shapeRadius: 0
    property color ink: ThemeBackend.text
    property bool hovered: false
    property bool pressed: false
    property bool active: ThemeBackend.orbit

    visible: active
    z: 50

    // state layer
    Rectangle {
        anchors.fill: parent
        radius: ripple.shapeRadius
        color: ripple.ink
        opacity: ripple.pressed ? 0.12 : (ripple.hovered ? 0.08 : 0)
        Behavior on opacity { NumberAnimation { duration: 150 * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
    }

    property real cx: width / 2
    property real cy: height / 2
    property real spread: 0
    property real inkAlpha: 0
    readonly property real maxRadius: Math.sqrt(Math.pow(Math.max(cx, width - cx), 2) + Math.pow(Math.max(cy, height - cy), 2)) + 6

    function press(x, y) {
        if (!active) return;
        cx = x; cy = y;
        fadeOut.stop();
        grow.stop();
        spread = 0;
        inkAlpha = 0.16;
        grow.start();
    }
    function release() {
        if (!active) return;
        fadeOut.restart();
    }

    NumberAnimation {
        id: grow
        target: ripple
        property: "spread"
        from: 0
        to: ripple.maxRadius
        duration: 420 * Math.max(0.35, ThemeBackend.animScale)
        easing.type: Easing.BezierSpline
        easing.bezierCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    }
    SequentialAnimation {
        id: fadeOut
        // let the ink reach most of the control before it lifts
        PauseAnimation { duration: grow.running ? 120 * Math.max(0.35, ThemeBackend.animScale) : 0 }
        NumberAnimation { target: ripple; property: "inkAlpha"; to: 0; duration: 300 * Math.max(0.35, ThemeBackend.animScale); easing.type: Easing.OutCubic }
    }

    ShaderEffect {
        anchors.fill: parent
        visible: ripple.inkAlpha > 0.001 && Caching.monolithDir !== ""
        property vector2d itemSize: Qt.vector2d(width, height)
        property real shapeRadius: ripple.shapeRadius
        property vector2d center: Qt.vector2d(ripple.cx, ripple.cy)
        property real rippleRadius: ripple.spread
        property color inkColor: ripple.ink
        property real inkAlpha: ripple.inkAlpha
        fragmentShader: Caching.monolithDir ? ("file://" + Caching.monolithDir + "/assets/shaders/ui/ripple.frag.qsb") : ""
    }
}
