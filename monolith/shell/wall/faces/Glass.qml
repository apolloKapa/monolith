import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// A widget's card, as its Background setting says: "blur" the wallpaper behind it blurred under a
// tint of the theme's surface, "normal" a solid card, "clear" no card at all.
// Without a backdrop (the editor's palette) a blurred card is just the tinted card.
Item {
    id: g
    property var ctx: null
    // the look's own rounding, unless the widget's Rounding setting says otherwise
    property real radius: Theme.corner(80, 12)
    readonly property real r: ctx && ctx.opt && Number(ctx.opt("radius", -1)) >= 0 ? Math.min(Number(ctx.opt("radius", -1)), Math.min(width, height) / 2) : radius
    // blurred, the tint is lighter so the frosted wallpaper shows through
    property real tint: backdrop ? 0.38 : 0.55
    property color tintColor: Theme.m("surface_container", Theme.container)
    // where this card sits inside its widget (for the part of the wallpaper behind it)
    property real dx: 0
    property real dy: 0
    readonly property string mode: ctx && ctx.opt ? String(ctx.opt("background", "blur")) : "blur"
    readonly property Item backdrop: ctx && mode === "blur" ? ctx.backdrop : null
    // Blur strength (0.1..1): the wallpaper behind is shrunk before it's blurred, so the blur
    // reaches much further than the effect's own radius (and costs less)
    readonly property real strength: ctx && ctx.opt ? Math.max(0.1, Math.min(1, Number(ctx.opt("blurStrength", 0.8)))) : 0.8
    readonly property real shrink: 1 + strength * 11

    // the wallpaper behind the card, shrunk (smoothly) and drawn back at full size, then blurred
    // as a layer effect and cut to the card's shape. (A MultiEffect reading the cropped texture
    // directly as its source drew nothing at all once blur was on.)
    Item {
        id: frost
        anchors.fill: parent
        visible: !!g.backdrop
        layer.enabled: visible
        layer.effect: MultiEffect {
            blurEnabled: true; blur: 1.0; blurMax: 64
            saturation: 0.15
            maskEnabled: true
            maskSource: mask
        }
        ShaderEffectSource {
            anchors.fill: parent
            sourceItem: g.backdrop
            sourceRect: g.backdrop && g.ctx ? Qt.rect(g.ctx.origin.x + g.dx, g.ctx.origin.y + g.dy, g.width, g.height) : Qt.rect(0, 0, 0, 0)
            textureSize: Qt.size(Math.max(1, Math.round(g.width / g.shrink)), Math.max(1, Math.round(g.height / g.shrink)))
            smooth: true
            live: true
            hideSource: false
        }
    }
    Rectangle { id: mask; anchors.fill: parent; radius: g.r; visible: false; layer.enabled: true }
    Rectangle {
        anchors.fill: parent
        visible: g.mode !== "clear"
        radius: g.r
        color: g.mode === "normal" ? Qt.alpha(g.tintColor, 1) : Qt.alpha(g.tintColor, g.backdrop ? g.tint : Math.max(g.tint, 0.85))
        border.width: Theme.outlineW
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Qt.alpha(Theme.text, 0.06)
    }
}
