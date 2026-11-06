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
    property real radius: Theme.corner(80, 12)
    property real tint: 0.55
    property color tintColor: Theme.m("surface_container", Theme.container)
    // where this card sits inside its widget (for the part of the wallpaper behind it)
    property real dx: 0
    property real dy: 0
    readonly property string mode: ctx && ctx.opt ? String(ctx.opt("background", "blur")) : "blur"
    readonly property Item backdrop: ctx && mode === "blur" ? ctx.backdrop : null

    ShaderEffectSource {
        id: src
        sourceItem: g.backdrop
        sourceRect: g.backdrop && g.ctx ? Qt.rect(g.ctx.origin.x + g.dx, g.ctx.origin.y + g.dy, g.width, g.height) : Qt.rect(0, 0, 0, 0)
        visible: false
        live: true
        hideSource: false
    }
    MultiEffect {
        anchors.fill: parent
        visible: !!g.backdrop
        source: src
        blurEnabled: true; blur: 1.0; blurMax: 48
        maskEnabled: true
        maskSource: mask
    }
    Rectangle { id: mask; anchors.fill: parent; radius: g.radius; visible: false; layer.enabled: true }
    Rectangle {
        anchors.fill: parent
        visible: g.mode !== "clear"
        radius: g.radius
        color: g.mode === "normal" ? Qt.alpha(g.tintColor, 1) : Qt.alpha(g.tintColor, g.backdrop ? g.tint : Math.max(g.tint, 0.85))
        border.width: Theme.outlineW
        border.color: Theme.outlineW > 0 ? Theme.outlineColor : Qt.alpha(Theme.text, 0.06)
    }
}
