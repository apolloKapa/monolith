pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's own part of niri's config: ~/.config/niri/config/monolith-shell.kdl (included from
// config.kdl, added once). Only what the shell's settings need from niri: the blur's strength,
// and Desktop mode's rule (core/Desk.qml).
Singleton {
    id: ns
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri"
    readonly property int passes: Number(Store.get("theme.blurStrength", 3))
    readonly property string text: "// Written by Monolith from its settings (Theme → Effects). Changes here are replaced.\n"
        + "blur {\n    passes " + passes + "\n    offset " + (1 + passes * 0.6).toFixed(1) + "\n}\n"
        // Desktop mode (core/Desk.qml): windows open floating
        + (Desk.on && Desk.floating ? "\n// Desktop mode\nwindow-rule {\n    open-floating true\n}\n" + Desk.niriSizeRules : "")
        // (Qt apps' own title bars in Desktop mode: Adwaita-like ones from QAdwaitaDecorations, when
        // it's installed, instead of Qt's plain blue "bradient". Never without it: a missing one
        // left Qt apps with no title bar at all)
        + (Desk.on && Desk.titlebars && qtAdwaita ? "\nenvironment {\n    QT_WAYLAND_DECORATION \"adwaita\"\n}\n" : "")
    // (niri's only: on Hyprland it made a stray ~/.config/niri with just this file in it. Written
    // once the settings are read too, not only when they change: Desktop mode switched on under
    // Hyprland never got its rule here, and windows opened tiled on niri)
    readonly property bool onNiri: Quickshell.env("NIRI_SOCKET") !== null && Quickshell.env("NIRI_SOCKET") !== ""
    onTextChanged: if (Store.loaded && onNiri) later.restart()
    Connections { target: Store; function onLoadedChanged() { if (Store.loaded && ns.onNiri) later.restart(); } }
    Component.onCompleted: if (Store.loaded && onNiri) later.restart()
    Timer { id: later; interval: 500; onTriggered: { if (file.text() !== ns.text) file.setText(ns.text); include.running = true; } }
    FileView { id: file; path: ns.dir + "/config/monolith-shell.kdl"; printErrors: false }
    property bool qtAdwaita: false
    Process {
        running: ns.onNiri
        command: ["sh", "-c", "ls /usr/lib*/qt6/plugins/wayland-decoration-client/ /usr/lib/*/qt6/plugins/wayland-decoration-client/ 2>/dev/null | grep -qi adwaita && echo yes"]
        stdout: StdioCollector { onStreamFinished: ns.qtAdwaita = text.trim() === "yes" }
    }
    // the include line, once
    Process {
        id: include
        command: ["sh", "-c", "f=\"$1/config.kdl\"; [ -f \"$f\" ] && ! grep -q 'config/monolith-shell.kdl' \"$f\" && printf '\\ninclude \"config/monolith-shell.kdl\"\\n' >> \"$f\"; true", "_", ns.dir]
    }
}
