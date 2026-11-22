pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "styles.js" as S

// The look: which style (core/styles.js) and which colours. Colours are the wallpaper's
// (matugen), the style's own palette, or one of the colour themes in themes/. Theme.qml
// builds everything from this.
Singleton {
    id: look
    readonly property var styles: S.list
    // (the old Blur style was Orbit with see-through, blurred panels: it's that now, and blur is a
    // toggle for every style, Theme.blur)
    // (a style that's gone, removed in 2.9.66 or older: Material, the default)
    readonly property string styleId: { const v = Store.get("theme.style", "material"); return styles.some(s => s.id === v) ? v : "material"; }
    readonly property var style: styles.find(s => s.id === styleId) || styles[0]
    // "wallpaper", "style" (the style's own palette) or a theme's name; empty = the style's default
    readonly property string paletteName: Store.get("theme.palette", "") || (style.colors && !style.matugen ? "style" : "wallpaper")
    readonly property string themesDir: Qt.resolvedUrl("../themes").toString().replace("file://", "")
    property var themeNames: []
    property var fileColors: null
    // the theme as it comes (the style's own palette, or a theme file's)
    readonly property var baseColors: paletteName === "style" ? (style.colors || null) : (paletteName === "wallpaper" ? null : fileColors)
    // Your changes to a theme's colours (Settings → Style & colours → Edit colours), kept per
    // theme ("style" for a style's own palette): theme.overrides = { name: { key: "#rrggbb" } }.
    // Each one can be put back on its own; the theme file itself never changes.
    readonly property string editKey: paletteName === "style" ? "style:" + styleId : paletteName
    readonly property var overrides: { const o = Store.get("theme.overrides", {}) || {}; return o[editKey] || {}; }
    readonly property var rawColors: baseColors ? Object.assign({}, baseColors, overrides) : null
    function setColour(key, value) {
        const all = Object.assign({}, Store.get("theme.overrides", {}) || {});
        const mine = Object.assign({}, all[editKey] || {});
        if (baseColors && String(baseColors[key]).toLowerCase() === String(value).toLowerCase()) delete mine[key];
        else mine[key] = value;
        if (Object.keys(mine).length) all[editKey] = mine; else delete all[editKey];
        Store.set("theme.overrides", all);
    }
    function resetColour(key) { setColour(key, baseColors ? baseColors[key] : ""); }
    function resetColours() {
        const all = Object.assign({}, Store.get("theme.overrides", {}) || {});
        delete all[editKey];
        Store.set("theme.overrides", all);
    }
    // Dark or light. The wallpaper's colours come in both (theme.mode). A palette is one or the
    // other as it's written, so the switch did nothing with one picked: now the other mode is
    // the palette turned over (every colour keeps its hue, its lightness is mirrored, so a black
    // background becomes white, white text black, and what stood out still stands out).
    // theme.paletteFlip names the palette that's turned over: picking another starts as written.
    readonly property string nativeMode: rawColors ? (lum(Qt.color(rawColors.base || "#000000")) < 0.5 ? "dark" : "light") : ""
    readonly property bool flipped: !!rawColors && Store.get("theme.paletteFlip", "") === paletteName
    readonly property var colors: flipped ? flip(rawColors) : rawColors
    readonly property string mode: rawColors ? (flipped ? (nativeMode === "dark" ? "light" : "dark") : nativeMode) : Store.get("theme.mode", "dark")
    function setMode(v) {
        if (rawColors) { if (v === nativeMode) Store.unset("theme.paletteFlip"); else Store.set("theme.paletteFlip", paletteName); }
        Store.set("theme.mode", v);
    }
    function flip(src) {
        const out = {};
        for (const k in src) {
            const c = Qt.color(src[k]);
            if (!c.valid) { out[k] = src[k]; continue; }
            let l = 1 - c.hslLightness;
            // (a colour, not a grey: kept where it still reads as that colour)
            if (c.hslSaturation > 0.15) l = Math.max(0.3, Math.min(0.72, l));
            out[k] = Qt.hsla(Math.max(0, c.hslHue), c.hslSaturation, l, c.a).toString();
        }
        return out;
    }
    // a colour theme may give apps colours of their own (`apps`, e.g. Twilight: a dark shell
    // framing light apps) and say whether apps are dark or light (`appsMode`)
    property var fileApps: null
    property string fileAppsMode: ""
    readonly property bool fromFile: paletteName !== "style" && paletteName !== "wallpaper"
    readonly property var appColors: fromFile && !flipped ? fileApps : null
    // dark or light for the apps (scripts/app_colours.py mode): the wallpaper's follow your
    // setting; a palette's follow the palette itself (a light theme made apps light), or its appsMode
    readonly property string appsMode: {
        if (!colors) return Store.get("theme.mode", "dark");
        if (fromFile && !flipped && (fileAppsMode === "dark" || fileAppsMode === "light")) return fileAppsMode;
        return lum(Qt.color(colors.base || "#000000")) < 0.5 ? "dark" : "light";
    }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }

    function pickStyle(id) { followStyle(id); Store.set("theme.style", id); Store.set("theme.palette", ""); }

    // ── switching workspaces (Animations → Workspace switching) ──
    // the setting as it's kept, and handing it to the compositor: Hyprland gets Monolith's
    // animations file (scripts/hypr_anims.py), niri its workspace-switch spring. Fade (niri)
    // switches at once and Monolith draws it; Glitch is the compositor's slide with Monolith's
    // light over it, and "fx" the same with the style's own effect (island/WorkspaceFade.qml).
    // niri can't slide sideways or fade: Slide sideways switches at once too and Monolith wipes the
    // new workspace in; Slide and fade is niri's slide with Monolith's fade over it
    readonly property var wsDefault: ({ style: "slidevert", feel: "smooth", speed: "normal" })
    readonly property var wsStiffness: ({ relaxed: 450, normal: 900, fast: 1500, fastest: 2500 })
    readonly property var wsRatio: ({ smooth: 1.0, bouncy: 0.6 })
    function workspaceSwitch() { return Object.assign({}, wsDefault, Store.get("animations.workspaceSwitch", {}) || {}); }
    function applyWorkspaceSwitch(c) {
        Store.set("animations.workspaceSwitch", c);
        if (Niri.hyprland)
            Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/hypr_anims.py").toString().replace("file://", ""), "apply", JSON.stringify(c)]);
        // (Glitch, the style's effect, Slide and fade: niri's own slide, Monolith's over it; Fade and
        // Slide sideways: Monolith's over an instant switch)
        else if (c.style === "off" || c.style === "fade" || c.style === "slide")
            NiriConf.set("animations", "workspace-switch", "{ off; }");
        else
            NiriConf.set("animations", "workspace-switch", "{ spring damping-ratio=" + wsRatio[c.feel].toFixed(1)
                + " stiffness=" + wsStiffness[c.speed] + " epsilon=0.0001; }");
    }
    // a style that glitches (Cyberpunk) switches workspaces with the glitch too, and a style with
    // another effect of its own (Fjord's frost, Doodle's pencil…) with that ("fx"): picking it sets
    // it (remembering what you had), leaving it for a plain style puts that back if it's still set
    // (Glitch was an instant switch with the compositor's animation off, until 2.9.64 made it the
    // compositor's slide with light over it: set that once where it was already picked)
    Timer {
        interval: 3000; running: true
        onTriggered: {
            const c = look.workspaceSwitch();
            if (c.style === "glitch" && Store.get("animations.glitchSlide", false) !== true) {
                look.applyWorkspaceSwitch(c);
                Store.set("animations.glitchSlide", true);
            }
        }
    }
    function followStyle(id) {
        const next = styles.find(s => s.id === id);
        if (!next || next.id === style.id) return;
        const c = workspaceSwitch();
        const own = s => ["glitch", "fx"].indexOf(s) !== -1;
        const want = next.glitch === true ? "glitch" : (next.fx ? "fx" : "");
        if (want !== "" && c.style !== want) {
            if (!own(c.style)) Store.set("animations.workspaceSwitchBefore", c.style);
            c.style = want;
            applyWorkspaceSwitch(c);
        } else if (want === "" && (style.glitch === true || !!style.fx) && own(c.style)) {
            c.style = Store.get("animations.workspaceSwitchBefore", "") || wsDefault.style;
            applyWorkspaceSwitch(c);
        }
    }
    function pickPalette(name) { Store.set("theme.palette", name); }

    FileView {
        path: look.paletteName !== "style" && look.paletteName !== "wallpaper" ? look.themesDir + "/" + look.paletteName + ".json" : ""
        printErrors: false
        onLoaded: {
            try {
                const d = JSON.parse(text());
                look.fileColors = d.colors || null;
                look.fileApps = d.apps || null;
                look.fileAppsMode = d.appsMode || "";
            } catch (e) { look.fileColors = null; look.fileApps = null; look.fileAppsMode = ""; }
        }
        onLoadFailed: { look.fileColors = null; look.fileApps = null; look.fileAppsMode = ""; }
    }
    Process {
        running: true
        command: ["sh", "-c", "cd \"$1\" && ls *.json | sed 's/\\.json$//' | grep -vx Matugen", "_", look.themesDir]
        stdout: StdioCollector { onStreamFinished: look.themeNames = text.split("\n").filter(l => l) }
    }
}
