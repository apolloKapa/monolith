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
    readonly property string styleId: Store.get("theme.style", "material")
    readonly property var style: styles.find(s => s.id === styleId) || styles[0]
    // "wallpaper", "style" (the style's own palette) or a theme's name; empty = the style's default
    readonly property string paletteName: Store.get("theme.palette", "") || (style.colors && !style.matugen ? "style" : "wallpaper")
    readonly property string themesDir: Qt.resolvedUrl("../themes").toString().replace("file://", "")
    property var themeNames: []
    property var fileColors: null
    readonly property var colors: paletteName === "style" ? (style.colors || null) : (paletteName === "wallpaper" ? null : fileColors)

    function pickStyle(id) { Store.set("theme.style", id); Store.set("theme.palette", ""); }
    function pickPalette(name) { Store.set("theme.palette", name); }

    FileView {
        path: look.paletteName !== "style" && look.paletteName !== "wallpaper" ? look.themesDir + "/" + look.paletteName + ".json" : ""
        printErrors: false
        onLoaded: { try { look.fileColors = JSON.parse(text()).colors || null; } catch (e) { look.fileColors = null; } }
        onLoadFailed: look.fileColors = null
    }
    Process {
        running: true
        command: ["sh", "-c", "cd \"$1\" && ls *.json | sed 's/\\.json$//' | grep -vx Matugen", "_", look.themesDir]
        stdout: StdioCollector { onStreamFinished: look.themeNames = text.split("\n").filter(l => l) }
    }
}
