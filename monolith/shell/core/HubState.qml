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
    readonly property var pages: ["search", "quick", "notifications", "media", "calendar", "sound", "network", "clipboard", "windows", "capture", "gaming", "tools", "wellbeing", "keys", "settings"]

    // the wallpaper picker is its own panel in the middle of the screen (wall/WallpaperPicker)
    property bool wallOpen: false
    property string wallScreen: ""
    // keybinds and commands pass no screen: then it's the one you're on (the focused output),
    // not whichever screen was clicked last
    function target(screen) { return screen || Niri.focusedOutput || screenName; }
    function showWall(screen) { wallScreen = target(screen); open = false; wallOpen = true; }

    function show(p, screen) {
        if (p === "wallpaper") { showWall(screen); return; }
        if (p && pages.indexOf(p) !== -1) page = p;
        screenName = target(screen);
        wallOpen = false;
        open = true;
    }
    function toggle(p, screen) {
        if (p === "wallpaper") { if (wallOpen) wallOpen = false; else showWall(screen); return; }
        if (open && (!p || p === page)) { open = false; return; }
        show(p, screen);
    }
    function close() { open = false; }
    // open Search with text already typed (":" = emojis, "~/" = files)
    property string preset: ""
    signal presetRequested()
    function search(text) { show("search"); preset = text; presetRequested(); }
    // the widget editor: "" (closed), "desktop" or "lock", on this screen
    property string editWidgets: ""
    property string editScreen: ""
    // the desktop's right-click menu: where, and on which widget (if any)
    property var deskMenu: ({ screen: "", x: 0, y: 0, widget: "" })
    function openDeskMenu(screen, x, y, widget) { open = false; deskMenu = { screen: screen, x: x, y: y, widget: widget || "" }; }
    function closeDeskMenu() { deskMenu = { screen: "", x: 0, y: 0, widget: "" }; }
    property string editSelect: ""      // the widget the editor opens with selected
    function editWidgetsOn(mode, screen) { open = false; wallOpen = false; editScreen = target(screen); editWidgets = mode || "desktop"; }

    // the dock editor, on a screen (Settings → Dock, `monolith dock`)
    property string dockEdit: ""
    function editDock(screen) { open = false; dockEdit = ""; dockEdit = target(screen); }

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
    IpcHandler {
        target: "dock"
        function edit(): void { hub.editDock(); }
    }
    IpcHandler {
        target: "desktop"
        // the desktop's menu at the middle of the screen you're on (`monolith desktop-menu`)
        function menu(): void { const sc = Quickshell.screens.find(x => x.name === hub.target("")) || Quickshell.screens[0]; hub.openDeskMenu(sc.name, sc.width / 2 - 125, sc.height / 2 - 150, ""); }
        function widget(id: string): void { const sc = Quickshell.screens.find(x => x.name === hub.target("")) || Quickshell.screens[0]; hub.openDeskMenu(sc.name, sc.width / 2 - 125, sc.height / 2 - 150, id); }
    }
    IpcHandler {
        target: "widgets"
        // the widget editor: desktop | lock
        function edit(mode: string): void { hub.editWidgetsOn(mode); }
        function done(): void { hub.editWidgets = ""; }
    }
}
