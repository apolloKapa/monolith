pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which hub page is open (if any), and on which screen. Opened from the status line,
// keybinds (`qs ipc -p … call hub toggle search`) or other pages.
Singleton {
    id: hub
    property bool open: false
    property string page: "search"
    property string screenName: ""
    readonly property var pages: ["search", "quick", "notifications", "media", "calendar", "sound", "network", "clipboard", "windows", "capture", "gaming", "tools", "wellbeing", "keys", "wallpaper", "settings"]

    function show(p, screen) {
        if (p && pages.indexOf(p) !== -1) page = p;
        if (screen) screenName = screen;
        open = true;
    }
    function toggle(p, screen) {
        if (open && (!p || p === page)) { open = false; return; }
        show(p, screen);
    }
    function close() { open = false; }
    // open Search with text already typed (":" = emojis, "~/" = files)
    property string preset: ""
    signal presetRequested()
    function search(text) { show("search"); preset = text; presetRequested(); }
    // the control center's tab: controls | overview | monitor
    property string ccTab: "controls"
    // Settings opened at a section (keybinds, the island, other pages)
    property string settingsSection: "appearance"
    function openSettings(section, screen) { if (section) settingsSection = section; show("settings", screen); }
    function step(d) { page = pages[(pages.indexOf(page) + d + pages.length) % pages.length]; }

    IpcHandler {
        target: "hub"
        function toggle(page: string): void { hub.toggle(page); }
        function open(page: string): void { hub.show(page); }
        function close(): void { hub.close(); }
        function search(text: string): void { hub.search(text); }
        // the control center at a tab: controls | overview | monitor
        function controlcenter(tab: string): void { if (tab) hub.ccTab = tab; hub.show("quick"); }
    }
    IpcHandler {
        target: "settings"
        function open(section: string): void { hub.openSettings(section); }
    }
    IpcHandler {
        target: "status"
        // auto-hide on/off (Super+A)
        function toggle(): void { Store.set("status.autohide", Store.get("status.autohide", false) !== true); }
    }
}
