import QtQuick
import "../../core"

// The root of every look: fills the widget and reaches its WidgetFace as `ctx`.
Item {
    anchors.fill: parent
    readonly property var ctx: parent && parent.ctx !== undefined ? parent.ctx : null
    readonly property bool live: ctx ? ctx.live : false
    readonly property bool editing: ctx ? ctx.editing === true : false
    readonly property var clock: ctx ? ctx.clock : null
    readonly property date now: clock ? clock.date : new Date()
    readonly property var player: ctx ? ctx.player : null
    function opt(k, d) { return ctx ? ctx.opt(k, d) : d; }

    // the widget's own colours (Main colour / Accent colour in its settings): a theme colour by
    // name or any #rrggbb; empty means the theme's own
    function colorOpt(k, d) {
        const v = String(opt(k, "") || "");
        if (v === "") return d;
        const roles = { text: Theme.text, accent: Theme.accent, white: "#ffffff", black: "#000000",
            primary: Theme.m("primary", Theme.accent), secondary: Theme.m("secondary", Theme.subtext), tertiary: Theme.m("tertiary", Theme.accent) };
        if (roles[v] !== undefined) return roles[v];
        return /^#[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$/.test(v) ? v : d;
    }
    readonly property bool hasMain: String(opt("mainColor", "") || "") !== ""
    readonly property bool hasAccent: String(opt("accentColor", "") || "") !== ""
    readonly property color mainC: colorOpt("mainColor", Theme.text)
    readonly property color accentC: colorOpt("accentColor", Theme.accent)
    readonly property color subC: hasMain ? Qt.alpha(mainC, 0.72) : Theme.subtext
}
