pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Apps in the shell's colours (Settings → App colours: kitty, GTK, Qt), and fastfetch's preset
// coloured to match. Written again whenever the palette (the wallpaper) or dark/light changes.
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
    FileView {
        path: Quickshell.env("HOME") + "/.local/state/monolith/next-palette.json"
        watchChanges: true
        printErrors: false
        onFileChanged: { reload(); ac.apply(); }
    }
    onTargetsChanged: apply()
}
