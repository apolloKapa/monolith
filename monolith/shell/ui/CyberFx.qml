import QtQuick
import "../core"

// A style's own motion (Theme.fxKind): Cyberpunk's (shaders/cyber.frag: something appearing
// glitches in, something going is taken by the Blackwall), and each other heavy style's
// (shaders/fx_<kind>.frag, the same inputs: Doodle draws things in and rubs them out, Terminal
// types them in and switches them off like a CRT, and so on; see Theme.fxKind). Put one next to what moves and give it that
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
    // (false: not for this one, whatever the style: the dock only glitches with Cyberpunk)
    property bool allowed: true
    // what it's on: a panel (a card, the dock: a solid shape, its edge kept sharp) or loose
    // content with nothing behind it (a page of a menu: its edge is the blurred shape of what's on it)
    property bool content: false
    readonly property bool on: allowed && Theme.cyber && !!target && target.visible && target.opacity > 0.001 && (going ? p > 0.001 : p < 0.999)
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
            // two colours for the effect: Cyberpunk's red and cyan; the pencil's ink and the accent
            // (Doodle), the phosphor and the text (Terminal); the ink and the accent elsewhere
            property color red: Theme.fxKind === "cyber" ? Theme.danger : (Theme.fxKind === "terminal" ? Theme.accent : Theme.text)
            property color cyan: Theme.fxKind === "terminal" ? Theme.text : Theme.accent
            // how solid the panels are (Fjord's frost lies over them as one even sheet that solid)
            property real base: Theme.see
            property real loose: fx.content ? 1 : 0
            // the panel's colour (solid) and its corner radius, so what an effect draws itself
            // (Doodle's pencil, Concrete's dust, Industrial's shutter, Fjord's ice) matches it
            property color panel: Qt.rgba(Theme.card.r, Theme.card.g, Theme.card.b, 1)
            property real radius: fx.content || !fx.target ? 0 : (fx.target.blurRadius !== undefined ? fx.target.blurRadius : (fx.target.radius !== undefined ? fx.target.radius : 0))
            fragmentShader: Qt.resolvedUrl(Theme.fxKind === "cyber" ? "shaders/cyber.frag.qsb" : "shaders/fx_" + Theme.fxKind + ".frag.qsb")
        }
    }
}
