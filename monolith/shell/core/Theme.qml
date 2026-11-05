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
    function c(name, fallback) { return pal[name] ? pal[name] : fallback; }
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
    readonly property string fontFamily: Store.get("theme.font", "") !== "" ? Store.get("theme.font", "") : defaultFont
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
    readonly property color card: m("surface_container_low", mix(_base, _s0, 0.55))      // the hub, the dock
    readonly property color container: m("surface_container", _s0)                        // groups inside a card
    readonly property color containerHigh: m("surface_container_high", _s1)               // rows, tiles
    readonly property color control: m("surface_container_highest", _s2)                  // bubbles, tracks, chips
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
    readonly property real radius: Math.max(0, radiusSetting)
    function corner(height, extra) { return Math.max(0, Math.min(height / 2, radius + (extra || 0))); }

    // ── motion (Material: emphasized decelerate in, emphasized accelerate out) ──
    readonly property var enterCurve: [0.05, 0.7, 0.1, 1.0, 1.0, 1.0]
    readonly property var exitCurve: [0.3, 0.0, 0.8, 0.15, 1.0, 1.0]
    readonly property var standardCurve: [0.2, 0.0, 0.0, 1.0, 1.0, 1.0]
    readonly property int enterMs: 500
    readonly property int exitMs: 200
    readonly property int moveMs: 380

    // ── the island (status line + hub in one shape hanging from the top edge) ──
    readonly property color frame: m("surface", mix(_base, _s0, 0.35))   // the island's fill
    readonly property real islandH: 40          // collapsed: the bar's height
    readonly property real islandMinW: 460      // collapsed: never narrower
    readonly property real islandEar: 20        // the concave curve joining the screen edge
    readonly property real islandPad: 12        // inside, around the content
    readonly property real islandGap: 8         // between the island and the screen edge when open
    readonly property real islandRadius: Math.max(14, radius + 12)  // its lower corners when open
    // springs for the island's size (a little overshoot, settles fast)
    readonly property real springK: 4.2
    readonly property real springDamp: 0.42
    readonly property real springMass: 1.0
    // the soft shadow under floating shapes (drawn by the shell, no compositor blur)
    readonly property real shadowBlur: 0.9
    readonly property color shadowColor: Qt.rgba(0, 0, 0, dark ? 0.55 : 0.28)
    readonly property real shadowY: 6

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
