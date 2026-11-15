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
    // the widget's own Font (the clocks' settings): that family, else the look's own `d`
    // the clocks' Colouring: one colour (Main colour), a gradient (its way and two colours) or a
    // colour for each digit. A gradient is laid over the digits drawn white (layer.effect:
    // GradientTint, gradVec its way); each digit's colour goes into the text (inked())
    readonly property string colorMode: String(opt("colorMode", "solid") || "solid")
    readonly property bool gradientOn: colorMode === "gradient"
    readonly property bool digitsOn: colorMode === "digits"
    readonly property color gradFrom: colorOpt("gradFrom", Theme.accent)
    readonly property color gradTo: colorOpt("gradTo", Theme.text)
    readonly property var gradWays: ({ down: [0, 1], up: [0, -1], right: [1, 0], left: [-1, 0],
        downRight: [1, 1], upRight: [1, -1], downLeft: [-1, 1], upLeft: [-1, -1] })
    readonly property vector2d gradVec: { const v = gradWays[String(opt("gradDir", "down"))] || [0, 1]; return Qt.vector2d(v[0], v[1]); }
    // what a digit's text is drawn in: white under a gradient, else `d`
    function inkColor(d) { return gradientOn ? "#ffffff" : d; }
    function digitColor(i, d) { return colorOpt("digit" + (i + 1), d); }
    // the time's text with each digit in its colour (rich text: textFormat textFormatFor()),
    // counting digits from `first` (the minutes of "mm" are digits 2 and 3); the rest in `d`
    function inked(s, d, first) {
        if (!digitsOn) return s;
        let out = "", i = first || 0;
        const hex = c => { const q = Qt.color(c); const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2); return "#" + h(q.r) + h(q.g) + h(q.b); };
        for (const ch of String(s)) {
            if (ch >= "0" && ch <= "9") { out += '<font color="' + hex(digitColor(i, d)) + '">' + ch + "</font>"; i++; }
            else out += '<font color="' + hex(d) + '">' + (ch === "<" ? "&lt;" : ch) + "</font>";
        }
        return out;
    }
    readonly property int textFormatFor: digitsOn ? Text.StyledText : Text.PlainText
    readonly property string fontPick: String(opt("font", "") || "")
    function fontOr(d) { return fontPick !== "" ? fontPick : d; }
}
