pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// The user's preferences that the new shell shares with Monolith's settings file
// (read-only until the new Settings app exists): dock apps, terminal, favourites.
Singleton {
    id: prefs
    readonly property string file: (Quickshell.env("XDG_CONFIG_HOME") || (Quickshell.env("HOME") + "/.config")) + "/monolith/settings.json"
    property var raw: ({})
    readonly property var dockApps: (raw.dock && Array.isArray(raw.dock.apps)) ? raw.dock.apps : []
    readonly property var favorites: (raw.launcher && Array.isArray(raw.launcher.favorites)) ? raw.launcher.favorites : []
    readonly property string terminal: Store.get("search.terminal", "") !== "" ? Store.get("search.terminal", "") : ((raw.launcher && raw.launcher.terminalCommand) ? raw.launcher.terminalCommand : "kitty -e")

    FileView {
        path: prefs.file
        watchChanges: true
        onFileChanged: reload()
        onLoaded: { try { prefs.raw = JSON.parse(text()); } catch (e) {} }
    }
}
