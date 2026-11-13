pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The shell's own part of niri's config: ~/.config/niri/config/monolith-shell.kdl (included from
// config.kdl, added once). Only what the shell's settings need from niri: the blur's strength.
Singleton {
    id: ns
    readonly property string dir: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/niri"
    readonly property int passes: Number(Store.get("theme.blurStrength", 3))
    readonly property string text: "// Written by Monolith from its settings (Theme → Effects). Changes here are replaced.\n"
        + "blur {\n    passes " + passes + "\n    offset " + (1 + passes * 0.6).toFixed(1) + "\n}\n"
    // (niri's only: on Hyprland it made a stray ~/.config/niri with just this file in it)
    onTextChanged: if (Store.loaded && !Niri.hyprland) later.restart()
    Timer { id: later; interval: 500; onTriggered: { file.setText(ns.text); include.running = true; } }
    FileView { id: file; path: ns.dir + "/config/monolith-shell.kdl"; printErrors: false }
    // the include line, once
    Process {
        id: include
        command: ["sh", "-c", "f=\"$1/config.kdl\"; [ -f \"$f\" ] && ! grep -q 'config/monolith-shell.kdl' \"$f\" && printf '\\ninclude \"config/monolith-shell.kdl\"\\n' >> \"$f\"; true", "_", ns.dir]
    }
}
