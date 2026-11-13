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
    // Liquid glass: panes are glass (ui/LiquidPane, shaders/glass.frag) with only a whisper of
    // fill over them; the compositor blur behind them is on unless you turned it off
    readonly property bool liquid: Look.style.liquid === true
    readonly property real see: (liquid ? 0.08 : (Look.style.opaque === false ? 0.74 : 1)) * panelOpacity
    // blur behind the shell's panels (the compositor does it; strength in niri's config)
    // blur behind panels: a toggle for every style but Liquid glass (which is glass already);
    // on by default for anyone who'd picked the old Blur style
    readonly property bool blur: !liquid && Store.get("theme.blur", Store.get("theme.style", "") === "blur") === true
    // effects (Theme → Effects): film grain on panels, a light along their top edge, and menus
    // that unfold from a thin line (the old shell's theme.effects carry over)
    readonly property var oldFx: Prefs.raw.theme && Prefs.raw.theme.effects ? Prefs.raw.theme.effects : ({})
    readonly property bool fxGrain: Store.get("theme.effects.grain", oldFx.grain === true) === true
    readonly property bool fxEdge: Store.get("theme.effects.edge", oldFx.edge === true) === true
    readonly property bool fxUnfold: Store.get("theme.effects.unfold", oldFx.unfold === true) === true && animOn
    readonly property color card: Qt.alpha(oled ? "#000000" : m("surface_container_low", mix(_base, _s0, 0.55)), see)  // the hub, the dock
    // (with a palette: mantle, surface0, surface1; surface2 is ink in some styles)
    // (liquid glass: the groups, rows and chips inside a pane are see-through too)
    readonly property color container: Qt.alpha(oled ? "#0d0d0d" : m("surface_container", Look.colors ? c("mantle", _s0) : _s0), liquid ? 0.34 : 1)            // groups inside a card
    readonly property color containerHigh: Qt.alpha(oled ? "#171717" : m("surface_container_high", Look.colors ? _s0 : _s1), liquid ? 0.4 : 1)                 // rows, tiles
    readonly property color control: Qt.alpha(oled ? "#242424" : m("surface_container_highest", Look.colors ? _s1 : _s2), liquid ? 0.5 : 1)                    // bubbles, tracks, chips
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
    // continuous corners (Appearance → Corner rounding): corners are superellipse arcs that ease
    // out of the straight sides instead of quarter circles (ui/SmoothRect); 0: plain round corners
    readonly property real cornerSmooth: Look.style.square || Store.get("theme.continuousCorners", true) === false ? 0
                                         : Math.max(0, Math.min(1, Number(Store.get("theme.cornerSmoothing", 0.6))))

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
    // how everything appears and goes: a fade with a little zoom (from popScale up to full size in,
    // back down out), popInMs / popOutMs long, on the enter / exit curves
    readonly property real popScale: animOn ? 0.94 : 1
    readonly property int popInMs: Math.round(320 * animScale)
    readonly property int popOutMs: Math.round(180 * animScale)

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
    // or down the left or right side ("" for top / bottom): a vertical bar with its own window
    // (island/SideBar.qml); its menus open as floating cards beside it
    readonly property string barSide: ["left", "right"].indexOf(Store.get("bar.position", "top")) !== -1 ? Store.get("bar.position", "top") : ""
    // the room a side bar takes from the screen's edge
    // the edge the bar is on: top, bottom, left or right
    readonly property string barEdge: barSide !== "" ? barSide : (barBottom ? "bottom" : "top")
    readonly property real sideRoom: barSide !== "" ? islandH + barMargin : 0
    // where a card dropping out of the bar's module (sound, notifications, the media peek) goes:
    // under it, over it (bar at the bottom), or beside it (side bars); (px, py) is the module's
    // point on the bar's inner edge, the card w × h in an area aw × ah
    function dropPos(px, py, w, h, aw, ah) {
        if (barSide !== "")
            return Qt.point(barSide === "left" ? px + 10 : px - w - 10, Math.max(12, Math.min(ah - h - 12, py - h / 2)));
        return Qt.point(Math.max(12, Math.min(aw - w - 12, px - w / 2)), barBottom ? py - h - 10 : py + 10);
    }
    readonly property int dropOrigin: barSide === "left" ? Item.Left : (barSide === "right" ? Item.Right : (barBottom ? Item.Bottom : Item.Top))
    readonly property bool fullBar: barStyle !== "island"                         // spread across the screen
    readonly property bool barFloats: barStyle === "solid" || barStyle === "modular" // off the edge
    readonly property real barMargin: barFloats ? Number(Store.get("bar.margin", 8)) : 0
    readonly property real frameW: barStyle === "frame" ? Number(Store.get("bar.frameWidth", 8)) : 0
    readonly property real islandMinW: Number(Store.get("bar.minWidth", 460))   // collapsed island: never narrower
    readonly property real barLength: barStyle === "frame" ? 1 : Number(Store.get("bar.length", 1))   // the bar's length (share of the screen; the Frame's is the whole width)
    // how the bar's length is set (Settings → Bar): "fit" its modules (never under islandMinW),
    // a "percent" of the screen, or exact "px". Unset: the island fits, the other styles take
    // their share of the screen. The Frame is always the whole width.
    readonly property string barLengthMode: barStyle === "frame" ? "percent" : (Store.get("bar.lengthMode", "") || (fullBar ? "percent" : "fit"))
    // a bar with a set length spreads its modules: left end, middle, right end
    readonly property bool barSpread: barLengthMode !== "fit"
    readonly property real barLengthPx: Number(Store.get("bar.lengthPx", 1200))
    // the bar's length on a screen this wide, holding modules this wide: never shorter than
    // its modules (they'd hang out of it), never longer than the screen
    function barWidth(screenW, contentW) {
        const room = Math.max(100, screenW - 2 * barMargin);
        const want = barLengthMode === "px" ? barLengthPx : (barLengthMode === "percent" ? room * barLength : Math.max(islandMinW, contentW));
        return Math.round(Math.min(room, Math.max(want, contentW)));
    }
    readonly property real barOpacity: Number(Store.get("bar.opacity", 1))      // the bar's own background (0: only its modules)
    readonly property bool barPills: Store.get("bar.pills", false) === true     // each module on its own pill
    readonly property bool square: Look.style.square === true                   // square styles: no rounding anywhere
    readonly property real islandEar: square ? 0 : 20   // the concave curve joining the screen edge
    readonly property real islandPad: 12        // inside, around the content
    readonly property real islandGap: 8         // between the island and the screen edge when open
    readonly property real islandRadius: square ? 0 : Math.max(14, radius + 12)  // its lower corners when open
    // the bar's corners (the island at rest, Solid, Modular's pills): they follow Appearance →
    // Corner rounding like everything else (a pill at the default and above, squarer below it,
    // square in square styles)
    function barRound(h) { return square ? 0 : Math.min(h / 2, radius + 8); }
    // the Frame draws the bar's background itself (one shape, so see-through styles don't double up)
    readonly property bool frameBand: barStyle === "frame" && Store.get("status.autohide", false) !== true
    // the island's "spring": a curve that overshoots a little and settles. (Not Qt's
    // SpringAnimation: that steps every 16 ms, so it moves at 60 fps on any screen.)
    readonly property var springCurve: [0.22, 1.0, 0.36, 1.1, 1, 1]
    readonly property int springMs: Math.round(520 * animScale)
    // menus growing and shrinking to fit: a quick start that settles, no overshoot (a spring's
    // overshoot made a menu look as if it rescaled every time its content changed)
    readonly property var sizeCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    // the soft shadow under floating shapes (drawn by the shell, no compositor blur)
    // (styles with a hard shadow: a solid offset copy in the ink colour)
    // (Theme → Effects → Shadows: on/off, strength, softness, distance, direction, colour)
    readonly property real hardShadow: Look.style.hardShadow || 0
    readonly property bool shadowOn: Store.get("theme.shadow.on", true) !== false
    readonly property real shadowStrength: Number(Store.get("theme.shadow.strength", 1))
    readonly property real shadowSoftness: Number(Store.get("theme.shadow.softness", 0.9))
    readonly property real shadowDistance: Number(Store.get("theme.shadow.distance", 6))
    readonly property real shadowSideways: Number(Store.get("theme.shadow.sideways", 0))
    readonly property string shadowTint: String(Store.get("theme.shadow.colour", "black"))
    // the colour shadows are made of (a theme colour by name, or any #rrggbb)
    readonly property color shadowBase: shadowTint === "accent" ? accent : (shadowTint === "ink" ? text : (/^#[0-9a-fA-F]{6}$/.test(shadowTint) ? shadowTint : "#000000"))
    readonly property real shadowBlur: hardShadow > 0 ? 0 : shadowSoftness
    // the same softness for RectangularShadow (its blur is in pixels: MultiEffect's blurMax is 32, but its blur looked tighter than that)
    readonly property real shadowPx: shadowBlur * 22
    // RectangularShadow (Qt 6.9+) is there: cards and the island draw their shadows with it. On an
    // older Qt they fall back to blurring a copy of their shape (slower while they change size)
    readonly property bool rectShadows: {
        try {
            const o = Qt.createQmlObject("import QtQuick; import QtQuick.Effects; RectangularShadow { visible: false }", theme, "rectShadowCheck");
            o.destroy();
            return true;
        } catch (e) {
            console.warn("Monolith: this Qt has no RectangularShadow (needs 6.9); shadows use the slower blur");
            return false;
        }
    }
    readonly property color shadowColor: !shadowOn ? "transparent" : (hardShadow > 0 ? text : Qt.alpha(shadowBase, Math.min(1, (dark ? 0.55 : 0.28) * shadowStrength)))
    readonly property real shadowY: hardShadow > 0 ? hardShadow : shadowDistance
    readonly property real shadowX: hardShadow > 0 ? hardShadow : shadowSideways
    // widgets' shadows (Theme → Effects → Shadows, and each widget's own Shadow setting):
    // off | soft | strong; the same colour and direction as the rest
    readonly property string widgetShadow: String(Store.get("widgets.shadow", "off"))

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
