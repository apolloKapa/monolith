pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The look: tonal layers built from the palette, the user's font and corner radius, and the
// motion curves. Everything visual asks this, nothing hard-codes a colour.
Singleton {
    id: theme

    readonly property string home: Quickshell.env("HOME") || ""
    readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || (home + "/.local/state")) + "/monolith"
    readonly property string configFile: (Quickshell.env("XDG_CONFIG_HOME") || (home + "/.config")) + "/monolith/settings.json"

    // ── palette: Material roles made from the wallpaper (Wall.qml), or the current
    // Monolith's palette until there is one, or a neutral fallback ──
    property var roles: ({})
    property var pal: ({})
    // a palette colour: the style's or colour theme's (Look), else the earlier Monolith's file
    function c(name, fallback) { const src = Look.colors || pal; return src[name] ? src[name] : fallback; }
    function role(name, fallback) {
        const r = roles[name];
        return r ? (r.color || r) : fallback;
    }
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/monolith/next-palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { theme.roles = JSON.parse(text()).colors || {}; } catch (e) {} }
    }
    FileView {
        path: theme.stateDir + "/qs_matugen_colors.json"
        watchChanges: true
        printErrors: false
        onFileChanged: reload()
        onLoaded: { try { theme.pal = JSON.parse(text()); } catch (e) {} }
    }
    // Material roles come as { dark: {color}, light: {color}, default: {color} }
    function m(name, fallback) {
        if (Look.colors) return fallback;      // a palette is picked: no wallpaper roles
        const r = roles[name];
        if (!r) return fallback;
        const pick = r[theme.modeName] || r["default"];
        return pick && pick.color ? pick.color : fallback;
    }
    readonly property string modeName: Store.get("theme.mode", "dark")

    // font and corner radius: this shell's setting, else Monolith's
    property string oldFont: "sans-serif"
    property real oldRadius: 12
    // the default is Google Sans when it's installed (the look is built around it)
    readonly property bool hasGoogleSans: Qt.fontFamilies().indexOf("Google Sans") !== -1
    readonly property string defaultFont: hasGoogleSans ? "Google Sans" : oldFont
    // your font, else the style's (when installed), else the default
    readonly property string styleFont: Look.style.font && Qt.fontFamilies().indexOf(Look.style.font) !== -1 ? Look.style.font : ""
    readonly property string fontFamily: Store.get("theme.font", "") !== "" ? Store.get("theme.font", "") : (styleFont || defaultFont)
    readonly property real radiusSetting: Number(Store.get("theme.radius", oldRadius))
    FileView {
        path: theme.configFile
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                const t = (JSON.parse(text()).theme) || {};
                if (t.fontFamily) theme.oldFont = t.fontFamily;
                if (t.borderRadius !== undefined) theme.oldRadius = Number(t.borderRadius);
            } catch (e) {}
        }
    }

    function lum(col) { return 0.2126 * col.r + 0.7152 * col.g + 0.0722 * col.b; }
    function mix(a, b, t) { return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t, 1); }

    readonly property color _base: c("base", "#111318")
    readonly property color _s0: c("surface0", "#1d2026")
    readonly property color _s1: c("surface1", "#272a31")
    readonly property color _s2: c("surface2", "#32363e")

    // the layers, lowest to highest
    readonly property bool oled: Look.style.oled === true
    // how solid panels are: see-through styles, and your setting (Theme → Effects)
    readonly property real panelOpacity: Number(Store.get("theme.panelOpacity", 1))
    readonly property real see: (Look.style.opaque === false ? 0.74 : 1) * panelOpacity
    // blur behind the shell's panels (the compositor does it; strength in niri's config)
    readonly property bool blur: Store.get("theme.blur", false) === true
    // effects (Theme → Effects): film grain on panels, a light along their top edge, and menus
    // that unfold from a thin line (the old shell's theme.effects carry over)
    readonly property var oldFx: Prefs.raw.theme && Prefs.raw.theme.effects ? Prefs.raw.theme.effects : ({})
    readonly property bool fxGrain: Store.get("theme.effects.grain", oldFx.grain === true) === true
    readonly property bool fxEdge: Store.get("theme.effects.edge", oldFx.edge === true) === true
    readonly property bool fxUnfold: Store.get("theme.effects.unfold", oldFx.unfold === true) === true && animOn
    readonly property color card: Qt.alpha(oled ? "#000000" : m("surface_container_low", mix(_base, _s0, 0.55)), see)  // the hub, the dock
    // (with a palette: mantle, surface0, surface1; surface2 is ink in some styles)
    readonly property color container: oled ? "#0d0d0d" : m("surface_container", Look.colors ? c("mantle", _s0) : _s0)            // groups inside a card
    readonly property color containerHigh: oled ? "#171717" : m("surface_container_high", Look.colors ? _s0 : _s1)                 // rows, tiles
    readonly property color control: oled ? "#242424" : m("surface_container_highest", Look.colors ? _s1 : _s2)                    // bubbles, tracks, chips
    readonly property bool dark: lum(card) < 0.5
    readonly property color hairline: Qt.alpha(m("outline_variant", dark ? "#ffffff" : "#000000"), roles.outline_variant ? 0.55 : 0.08)

    readonly property color text: m("on_surface", c("text", "#e3e2e9"))
    readonly property color subtext: m("on_surface_variant", c("subtext0", "#a9aab4"))
    readonly property color faint: Qt.alpha(text, 0.45)

    readonly property color accent: m("primary", c("mauve", "#b6c4ff"))
    readonly property color onAccent: m("on_primary", lum(accent) > 0.5 ? mix(accent, "#000000", 0.78) : "#ffffff")
    readonly property color accentContainer: m("primary_container", mix(_s1, accent, 0.35))
    readonly property color onAccentContainer: m("on_primary_container", text)
    // a selection: Material's secondary container
    readonly property color selected: m("secondary_container", mix(_s1, accent, 0.22))
    readonly property color ringTrack: Qt.alpha(text, 0.14)   // the empty part of rings and bars
    readonly property color danger: m("error", c("red", "#ffb4ab"))

    // ── shape ──
    // the base radius is the setting; nested shapes take it minus the gap (concentric)
    readonly property real radius: Look.style.square ? 0 : Math.max(0, radiusSetting * (Look.style.radiusScale || 1))
    // the style's outlines: on panels, cards and controls
    readonly property real outlineW: Look.style.outline ? Look.style.outline[0] : 0
    readonly property color outlineColor: ({ accent: accent, accentSoft: Qt.alpha(accent, 0.5), ink: text, text: text,
                                             rule: Qt.alpha(text, 0.22) })[Look.style.outlineRole || "rule"] || Qt.alpha(text, 0.22)
    function corner(height, extra) { return Math.max(0, Math.min(height / 2, radius + (extra || 0))); }

    // ── motion (Material: emphasized decelerate in, emphasized accelerate out) ──
    readonly property var enterCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var exitCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var standardCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    // animation speed (Theme → Effects): a multiplier on every duration; off = instant
    readonly property bool animOn: Store.get("theme.animations", true) !== false
    readonly property real animScale: animOn ? 1 / Math.max(0.2, Number(Store.get("theme.animSpeed", 1))) : 0
    readonly property int enterMs: Math.round(500 * animScale)
    readonly property int exitMs: Math.round(200 * animScale)
    readonly property int moveMs: Math.round(380 * animScale)
    readonly property int fastMs: Math.round(160 * animScale)      // hovers, colours, small state changes
    readonly property int shortMs: Math.round(260 * animScale)     // fades, small moves, switches
    // any other transition's length, scaled like the rest (0 when animations are off)
    function ms(n) { return Math.round(n * animScale); }

    // ── the island (status line + hub in one shape hanging from the top edge) ──
    readonly property color frame: Qt.alpha(oled ? "#000000" : m("surface", mix(_base, _s0, 0.35)), see)   // the island's fill
    readonly property real islandH: Number(Store.get("bar.height", 40))   // collapsed: the bar's height (Settings → Bar)
    // the bar's style (Settings → Bar): island (one pill hanging from the top), fill (a bar along
    // the top edge), frame (that, and a border round the whole screen), solid (one floating bar)
    // or modular (each section on its own floating pill)
    readonly property string barStyle: Store.get("bar.style", "") || (Store.get("bar.shape", "island") === "full" ? "fill" : "island")
    // the bar along the top (default) or the bottom of the screen (Settings → Bar); at the bottom
    // the island rises from the bottom edge and its menus grow upwards
    readonly property bool barBottom: Store.get("bar.position", "top") === "bottom"
    readonly property bool fullBar: barStyle !== "island"                         // spread across the screen
    readonly property bool barFloats: barStyle === "solid" || barStyle === "modular" // off the edge
    readonly property real barMargin: barFloats ? Number(Store.get("bar.margin", 8)) : 0
    readonly property real frameW: barStyle === "frame" ? Number(Store.get("bar.frameWidth", 8)) : 0
    readonly property real islandMinW: Number(Store.get("bar.minWidth", 460))   // collapsed island: never narrower
    readonly property real barLength: barStyle === "frame" ? 1 : Number(Store.get("bar.length", 1))   // the bar's length (share of the screen; the Frame's is the whole width)
    readonly property real barOpacity: Number(Store.get("bar.opacity", 1))      // the bar's own background (0: only its modules)
    readonly property bool barPills: Store.get("bar.pills", false) === true     // each module on its own pill
    readonly property bool square: Look.style.square === true                   // square styles: no rounding anywhere
    readonly property real islandEar: square ? 0 : 20   // the concave curve joining the screen edge
    readonly property real islandPad: 12        // inside, around the content
    readonly property real islandGap: 8         // between the island and the screen edge when open
    readonly property real islandRadius: square ? 0 : Math.max(14, radius + 12)  // its lower corners when open
    // a floating bar's (Solid, Modular) corners: a pill, square in square styles
    function barRound(h) { return square ? 0 : Math.min(h / 2, islandRadius + 6); }
    // the Frame draws the bar's background itself (one shape, so see-through styles don't double up)
    readonly property bool frameBand: barStyle === "frame" && Store.get("status.autohide", false) !== true
    // the island's "spring": a curve that overshoots a little and settles. (Not Qt's
    // SpringAnimation: that steps every 16 ms, so it moves at 60 fps on any screen.)
    readonly property var springCurve: [0.22, 1.0, 0.36, 1.1, 1, 1]
    readonly property int springMs: Math.round(520 * animScale)
    // the soft shadow under floating shapes (drawn by the shell, no compositor blur)
    // (styles with a hard shadow: a solid offset copy in the ink colour)
    readonly property real hardShadow: Look.style.hardShadow || 0
    readonly property real shadowBlur: hardShadow > 0 ? 0 : 0.9
    readonly property color shadowColor: hardShadow > 0 ? text : Qt.rgba(0, 0, 0, dark ? 0.55 : 0.28)
    readonly property real shadowY: hardShadow > 0 ? hardShadow : 6
    readonly property real shadowX: hardShadow

    // ── type ──
    readonly property int sizeTiny: 9
    readonly property int sizeSmall: 11
    readonly property int sizeBody: 13
    readonly property int sizeTitle: 16
    readonly property int sizeHeadline: 24
    readonly property int sizeDisplay: 44
    // Google's Material Symbols (ligatures: Icon { name: "wifi" })
    readonly property string iconFont: "Material Symbols Rounded"
}
