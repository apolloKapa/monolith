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
    readonly property string styleId: { const v = Store.get("theme.style", "material"); return v === "blur" ? "orbit" : v; }
    readonly property var style: styles.find(s => s.id === styleId) || styles[0]
    // "wallpaper", "style" (the style's own palette) or a theme's name; empty = the style's default
    readonly property string paletteName: Store.get("theme.palette", "") || (style.colors && !style.matugen ? "style" : "wallpaper")
    readonly property string themesDir: Qt.resolvedUrl("../themes").toString().replace("file://", "")
    property var themeNames: []
    property var fileColors: null
    readonly property var colors: paletteName === "style" ? (style.colors || null) : (paletteName === "wallpaper" ? null : fileColors)
    // a colour theme may give apps colours of their own (`apps`, e.g. Twilight: a dark shell
    // framing light apps) and say whether apps are dark or light (`appsMode`)
    property var fileApps: null
    property string fileAppsMode: ""
    readonly property bool fromFile: paletteName !== "style" && paletteName !== "wallpaper"
    readonly property var appColors: fromFile ? fileApps : null
    // dark or light for the apps (scripts/app_colours.py mode): the wallpaper's follow your
    // setting; a palette's follow the palette itself (a light theme made apps light), or its appsMode
    readonly property string appsMode: {
        if (!colors) return Store.get("theme.mode", "dark");
        if (fromFile && (fileAppsMode === "dark" || fileAppsMode === "light")) return fileAppsMode;
        return lum(Qt.color(colors.base || "#000000")) < 0.5 ? "dark" : "light";
    }
    function lum(c) { return 0.2126 * c.r + 0.7152 * c.g + 0.0722 * c.b; }

    function pickStyle(id) { Store.set("theme.style", id); Store.set("theme.palette", ""); }
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
