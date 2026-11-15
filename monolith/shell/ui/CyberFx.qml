import QtQuick
import "../core"

// The Cyberpunk style's motion (Theme.cyber, shaders/cyber.frag): something appearing glitches
// in, something going is taken by the Blackwall. Put one next to what moves and give it that
// item (`target`), how far along it is (`p`, 0 … 1: coming in, it's how much is there; going,
// how much the Blackwall has taken) and which way (`going`). The target is drawn through the
// effect only while it runs; before and after it's drawn as it is.
Item {
    id: fx
    property Item target: null
    property real p: 1
    property bool going: false
    // (and only while the target shows: one taken by the Blackwall stays at p 1, hidden or
    // see-through (the dock), and the effect and its frame clock would have run on for nothing)
    readonly property bool on: Theme.cyber && !!target && target.visible && target.opacity > 0.001 && (going ? p > 0.001 : p < 0.999)
    // seconds since it started, and a fresh pattern each time
    property real t: 0
    property real seed: 0
    visible: false
    onOnChanged: if (on) { t = 0; seed = Math.random() * 97; }
    FrameAnimation { running: fx.on; onTriggered: fx.t += frameTime }

    Binding { target: fx.target; property: "layer.enabled"; value: true; when: fx.on }
    Binding { target: fx.target; property: "layer.effect"; value: shader; when: fx.on }
    Component {
        id: shader
        ShaderEffect {
            property vector2d itemSize: Qt.vector2d(width, height)
            property real p: fx.p
            property real mode: fx.going ? 1 : 0
            property real t: fx.t
            property real seed: fx.seed
            property color red: Theme.danger
            property color cyan: Theme.accent
            fragmentShader: Qt.resolvedUrl("shaders/cyber.frag.qsb")
        }
    }
}
