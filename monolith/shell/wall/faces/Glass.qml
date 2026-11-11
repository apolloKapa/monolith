import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// A widget's card, as its Background setting says: "blur" the wallpaper behind it blurred under a
// tint of the theme's surface, "normal" (Opacity) a card as see-through as its Background opacity
// (solid at 100 %), "clear" no card at all.
// Without a backdrop (the editor's palette) a blurred card is just the tinted card.
Item {
    id: g
    property var ctx: null
    // the look's own rounding, unless the widget's Rounding setting says otherwise
    property real radius: Theme.corner(80, 12)
    readonly property real r: ctx && ctx.opt && Number(ctx.opt("radius", -1)) >= 0 ? Math.min(Number(ctx.opt("radius", -1)), Math.min(width, height) / 2) : radius
    // blurred, the tint is lighter so the frosted wallpaper shows through
    property real tint: Theme.liquid ? 0.06 : (backdrop ? 0.38 : 0.55)
    property color tintColor: Theme.m("surface_container", Theme.container)
    // where this card sits inside its widget (for the part of the wallpaper behind it)
    property real dx: 0
    property real dy: 0
    // (a Dot card's old Glass / Clear tones are its Background now)
    property string defaultMode: "blur"
    readonly property string mode: ctx && ctx.opt ? String(ctx.opt("background", defaultMode)) : defaultMode
    readonly property real cardOpacity: ctx && ctx.opt ? Math.max(0, Math.min(1, Number(ctx.opt("bgOpacity", 1)))) : 1
    readonly property Item backdrop: ctx && mode === "blur" ? ctx.backdrop : null
    // Blur strength (0.1..1): the wallpaper behind is shrunk before it's blurred, so the blur
    // reaches much further than the effect's own radius (and costs less)
    readonly property real strength: ctx && ctx.opt ? Math.max(0.1, Math.min(1, Number(ctx.opt("blurStrength", 0.8)))) : 0.8
    // (liquid glass is clearer: barely frosted, so the bending at its edges shows)
    readonly property real shrink: 1 + strength * 11

    // the wallpaper behind the card, shrunk (smoothly) and drawn back at full size, then blurred
    // as a layer effect and cut to the card's shape. (A MultiEffect reading the cropped texture
    // directly as its source drew nothing at all once blur was on.)
    Item {
        id: frost
        anchors.fill: parent
        visible: !!g.backdrop && !Theme.liquid
        layer.enabled: visible
        layer.effect: frostFx
        layer.smooth: true
        // a turned widget: the wallpaper behind its box on screen, turned back the other way
        ShaderEffectSource {
            readonly property int rot: g.ctx && g.ctx.rot !== undefined ? g.ctx.rot : 0
            readonly property bool side: rot % 180 !== 0
            anchors.centerIn: parent
            width: side ? parent.height : parent.width
            height: side ? parent.width : parent.height
            rotation: -rot
            sourceItem: g.backdrop
            sourceRect: !g.backdrop || !g.ctx ? Qt.rect(0, 0, 0, 0)
                : (rot === 0 ? Qt.rect(g.ctx.origin.x + g.dx, g.ctx.origin.y + g.dy, g.width, g.height) : Qt.rect(g.ctx.origin.x, g.ctx.origin.y, width, height))
            textureSize: Qt.size(Math.max(1, Math.round(width / g.shrink)), Math.max(1, Math.round(height / g.shrink)))
            smooth: true
            live: true
            hideSource: false
        }
    }
    Component {
        id: frostFx
        MultiEffect {
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.15
            maskEnabled: true
            maskSource: mask
        }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: g.r; visible: false; layer.enabled: true }
    Rectangle {
        anchors.fill: parent
        visible: g.mode !== "clear"
        radius: g.r
        color: g.mode === "normal" ? Qt.alpha(g.tintColor, g.cardOpacity) : Qt.alpha(g.tintColor, g.backdrop ? g.tint : Math.max(g.tint, 0.85))
        // (an all see-through card keeps no edge either)
        opacity: g.mode === "normal" ? Math.min(1, g.cardOpacity * 4) : 1
        border.width: Theme.outlineW
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Qt.alpha(Theme.text, 0.06)
    }
    // liquid glass: the card is a pane of glass, under the tint
    LiquidPane { anchors.fill: parent; z: -1; radius: g.r; visible: Theme.liquid && g.mode === "blur" }
}
