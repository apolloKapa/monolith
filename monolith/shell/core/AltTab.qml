pragma Singleton
import QtQuick
import Quickshell

// Alt+Tab is niri's own window switcher (live previews of each window, and it knows when Alt is
// let go, which a shell can't): this keeps it in the shell's look. Its highlight takes the
// theme's accent (red-ish urgent windows: the theme's danger colour) and the theme's roundness,
// written to niri's config (recent-windows → highlight) whenever they change. Settings →
// Windows → Alt+Tab ("In the theme's look") turns that off; the switcher's other options are
// there too. Not on Hyprland (it has its own).
Singleton {
    id: at
    readonly property bool follow: Store.get("alttab.theme", true) !== false && !Niri.hyprland
    function hex(c) { const h = v => ("0" + Math.round(v * 255).toString(16)).slice(-2); return "#" + h(c.r) + h(c.g) + h(c.b) + "ff"; }
    readonly property string active: hex(Qt.color(Theme.accent))
    readonly property string urgent: hex(Qt.color(Theme.danger))
    readonly property int corner: Math.round(Theme.corner(400, 6))
    // what's in niri's config now (read once at start, then what was written)
    property var have: null
    Component.onCompleted: NiriConf.read(["recent-windows/highlight|active-color", "recent-windows/highlight|urgent-color", "recent-windows/highlight|corner-radius"], r => {
        at.have = { active: NiriConf.unquote(r["recent-windows/highlight|active-color"]), urgent: NiriConf.unquote(r["recent-windows/highlight|urgent-color"]), corner: Number(r["recent-windows/highlight|corner-radius"]) };
        at.sync();
    })
    onActiveChanged: sync()
    onUrgentChanged: sync()
    onCornerChanged: sync()
    onFollowChanged: sync()
    function sync() { if (have && follow) later.restart(); }
    // (a moment after the last change: a wallpaper change moves every colour at once)
    Timer {
        id: later
        interval: 1200
        onTriggered: {
            if (!at.follow || !at.have) return;
            if (at.have.active !== at.active) NiriConf.set("recent-windows/highlight", "active-color", NiriConf.quote(at.active));
            if (at.have.urgent !== at.urgent) NiriConf.set("recent-windows/highlight", "urgent-color", NiriConf.quote(at.urgent));
            if (at.have.corner !== at.corner) NiriConf.set("recent-windows/highlight", "corner-radius", at.corner);
            at.have = { active: at.active, urgent: at.urgent, corner: at.corner };
        }
    }
}
