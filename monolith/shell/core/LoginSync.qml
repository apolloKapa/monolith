pragma Singleton
import QtQuick
import Quickshell

// The login screen (Monolith's SDDM theme) follows the desktop: when the wallpaper, your
// picture, the font or the colours change, scripts/login_sync.py copies them to
// /var/lib/monolith/login, which the installer made for it (it does nothing without it).
// A few seconds after the last change, so a run of changes (a new wallpaper's palette coming in
// colour by colour) is one copy.
Singleton {
    id: ls
    readonly property string wall: Wall.still(Wall.path)
    readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))
    readonly property string font: Theme.fontFamily
    readonly property bool light: !Theme.dark
    function hex(col) {
        const h = v => ("0" + Math.round(Math.max(0, Math.min(1, v)) * 255).toString(16)).slice(-2);
        return "#" + h(col.r) + h(col.g) + h(col.b);
    }
    // a see-through colour as it looks over the background (the hairline, a liquid style's rows)
    function over(col, under) {
        const a = col.a;
        return Qt.rgba(col.r * a + under.r * (1 - a), col.g * a + under.g * (1 - a), col.b * a + under.b * (1 - a), 1);
    }
    readonly property color base: Qt.rgba(Theme.frame.r, Theme.frame.g, Theme.frame.b, 1)
    // (the colours as the shell shows them: a style's or colour theme's too, not only the
    // wallpaper's; see-through ones as they look over the background)
    readonly property var colors: [
        "primary=" + hex(Theme.accent), "onPrimary=" + hex(Theme.onAccent),
        "surface=" + hex(base), "onSurface=" + hex(Theme.text), "onSurfaceVariant=" + hex(Theme.subtext),
        "container=" + hex(over(Theme.containerHigh, base)), "error=" + hex(Theme.danger), "outline=" + hex(over(Theme.hairline, base))
    ]
    readonly property string key: [wall, avatar, font, light].concat(colors).join("|")
    onKeyChanged: if (Store.loaded) later.restart()
    readonly property bool ready: Store.loaded
    onReadyChanged: if (ready) later.restart()
    Timer {
        id: later
        interval: 4000
        onTriggered: Quickshell.execDetached(["python3", Qt.resolvedUrl("../scripts/login_sync.py").toString().replace("file://", ""),
                                              ls.wall, ls.avatar, ls.font, ls.light ? "light" : "dark"].concat(ls.colors))
    }
}
