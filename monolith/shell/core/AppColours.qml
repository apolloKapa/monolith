pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Apps in the shell's colours (Settings → App colours: kitty, GTK, Qt), and fastfetch's preset
// coloured to match. Written again whenever the shell's colours change: the wallpaper, a colour
// theme or style, dark/light.
Singleton {
    id: ac
    readonly property var targets: ["kitty", "gtk", "qt"].filter(t => Store.get("apps." + t, false) === true)
    readonly property string script: Qt.resolvedUrl("../scripts/app_colours.py").toString().replace("file://", "")
    readonly property string ffScript: Qt.resolvedUrl("../scripts/fastfetch.py").toString().replace("file://", "")

    function apply() { later.restart(); }
    function switchOff(t) { Quickshell.execDetached(["python3", script, "off", t]); }
    Timer {
        id: later
        interval: 800
        onTriggered: {
            if (ac.targets.length > 0) Quickshell.execDetached(["python3", ac.script, "apply"].concat(ac.targets));
            Quickshell.execDetached(["python3", ac.ffScript, "render"]);
        }
    }
    // the colours the shell is really using, as Material roles in matugen's format, for the apps
    // and fastfetch: the wallpaper's own roles, or, with a colour theme or a style's colours
    // picked (Theme → Style & colours), roles made from those. Written to shell-palette.json.
    // the third colour (the second one in fastfetch's logo, …): the theme's teal, unless it's
    // Catppuccin's stock teal that many themes never changed (then it stayed mint whatever theme
    // you picked): a light shade of the theme's accent instead, so it follows the theme
    readonly property color tertiary: {
        const t = Theme.c("teal", "");
        const stock = !t || hex(Qt.color(t)) === "#94e2d5";
        const catppuccin = String(Store.get("theme.palette", "")).toLowerCase().indexOf("catppuccin") !== -1;
        return stock && !catppuccin ? Qt.tint(Theme.accent, Qt.rgba(1, 1, 1, Theme.dark ? 0.45 : 0.25)) : Qt.color(t);
    }
    function hex(c) { const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2); return "#" + h(c.r) + h(c.g) + h(c.b); }
    readonly property var shellRoles: {
        const out = {};
        if (!Look.colors) {
            for (const k in Theme.roles) { const r = Theme.roles[k]; out[k] = r.color || (r.default && r.default.color) || r; }
            if (Object.keys(out).length > 0) return out;
        }
        const c = (n, f) => Theme.c(n, f);
        const map = {
            primary: Theme.accent, on_primary: Theme.onAccent, primary_container: Theme.accentContainer, on_primary_container: Theme.onAccentContainer,
            secondary: c("blue", Theme.accent), on_secondary: c("crust", "#000000"), secondary_container: Theme.selected, on_secondary_container: Theme.text,
            tertiary: ac.tertiary, on_tertiary: c("crust", "#000000"), tertiary_container: Theme.control, on_tertiary_container: Theme.text,
            error: Theme.danger, on_error: c("crust", "#000000"),
            background: c("base", Theme.card), on_background: Theme.text, surface: c("base", Theme.card), on_surface: Theme.text,
            surface_variant: c("surface1", Theme.control), on_surface_variant: Theme.subtext,
            surface_container_lowest: c("crust", Theme.card), surface_container_low: c("mantle", Theme.card), surface_container: Theme.container,
            surface_container_high: Theme.containerHigh, surface_container_highest: Theme.control,
            outline: c("overlay0", Theme.subtext), outline_variant: c("surface2", Theme.control),
            inverse_surface: Theme.text, inverse_on_surface: c("base", Theme.card), inverse_primary: Theme.accentContainer,
            shadow: "#000000", scrim: "#000000", source_color: Theme.accent
        };
        for (const k in map) out[k] = hex(Qt.color(map[k]));
        return out;
    }
    readonly property string shellPalette: {
        // the wallpaper's roles go through as they are (with their dark and light variants)
        if (!Look.colors && Object.keys(Theme.roles).length > 0) return JSON.stringify({ colors: Theme.roles }, null, 1);
        const colors = {};
        for (const k in shellRoles) { const v = { color: shellRoles[k] }; colors[k] = { default: v, dark: v, light: v }; }
        return JSON.stringify({ colors: colors }, null, 1);
    }
    readonly property string paletteFile: Quickshell.env("HOME") + "/.local/state/monolith/shell-palette.json"
    onShellPaletteChanged: writeLater.restart()
    Timer { id: writeLater; interval: 400; onTriggered: { palFile.setText(ac.shellPalette + "\n"); ac.apply(); } }
    FileView { id: palFile; path: ac.paletteFile; printErrors: false }
    Component.onCompleted: writeLater.restart()
    onTargetsChanged: apply()
}
