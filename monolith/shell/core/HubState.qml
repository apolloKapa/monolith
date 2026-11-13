pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Which hub page is open (if any), and on which screen. Opened from the status line,
// keybinds (`qs ipc -p … call hub toggle search`) or other pages.
Singleton {
    id: hub
    property bool open: false
    onOpenChanged: { Sounds.play(open ? "open" : "close"); if (open) { peekScreen = ""; dropScreen = ""; } }
    // the bar's dropdowns: the bell and the volume drop a small card right under them
    // (status/NotifDrop.qml, status/SoundDrop.qml); which one, and where it hangs, in that
    // screen's coordinates
    property string dropKind: ""        // "notifications" | "sound" | "tray" | "system"
    property string dropScreen: ""
    property real dropX: 0
    property real dropY: 0
    function toggleDrop(kind, screen, x, y) {
        if (dropScreen === screen && dropKind === kind) { dropScreen = ""; return; }
        open = false; peekScreen = "";
        dropX = x; dropY = y; dropKind = kind; dropScreen = screen;
    }
    function closeDrop() { dropScreen = ""; }
    // a tray icon's menu (status/TrayMenu.qml): which icon's; a right click on another icon
    // switches to its menu, on the same one again puts it away
    property var trayItem: null
    function toggleTray(item, screen, x, y) {
        if (dropKind === "tray" && dropScreen === screen && trayItem === item) { dropScreen = ""; return; }
        open = false; peekScreen = "";
        trayItem = item; dropX = x; dropY = y; dropKind = "tray"; dropScreen = screen;
    }
    // the now-playing peek: a small player under the bar's media module while it's hovered
    // (status/MediaPeek.qml); where it hangs, in that screen's coordinates
    property string peekScreen: ""
    property real peekX: 0
    property real peekY: 0
    property bool peekModuleHover: false
    property bool peekCardHover: false
    readonly property bool peekWanted: peekModuleHover || peekCardHover
    onPeekWantedChanged: if (peekWanted) peekHide.stop(); else peekHide.restart()
    property Timer peekHide: Timer { interval: 280; onTriggered: hub.peekScreen = "" }
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

    // a different menu opened while the hub is closed (or still closing): it comes up on its
    // own, at its own size, instead of carrying on from the last one's closing animation (half
    // faded, the old page still fading out over it, the card stretching from the old size).
    // True only while the opening happens; animations that would carry on are skipped then.
    property bool snap: false
    // one open menu turning into another: the old page leaves quickly and the new one comes in
    // just after it, so the two don't sit on top of each other while the card morphs
    property bool switching: false
    function switched() { switching = true; switchEnd.restart(); }
    // view transitions: which way one open menu turns into another. +1: the new one is further
    // along the menus (pages) than the old, so it comes in from the right and the old one leaves
    // to the left; -1 the other way (hub/Page.qml)
    property int dir: 1
    function aim(p) { dir = pages.indexOf(p) >= pages.indexOf(page) ? 1 : -1; }
    // another menu in the open hub (tabs, "open in full", a tile's right click…): always through
    // here, so the old page leaves and the new one slides in instead of the two overlapping
    function go(p) {
        if (!p || p === page || pages.indexOf(p) === -1) return;
        if (open) { aim(p); switched(); }
        page = p;
    }
    property Timer switchEnd: Timer { interval: 450; onTriggered: hub.switching = false }
    function show(p, screen) {
        if (p === "wallpaper") { showWall(screen); return; }
        const next = p && pages.indexOf(p) !== -1 ? p : page;
        if (!open && next !== page) { snap = true; Qt.callLater(() => { hub.snap = false; }); }
        if (open && next !== page) { aim(next); switched(); }
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
    // a page gives the keyboard back to the island's field (after its own text box is done)
    signal refocus()
    // an administrator password is being asked for (status/PolkitDialog): menus that hold the
    // keyboard let go of it, or the dialog can't be typed in
    property bool authOpen: false
    // what the Network menu last found (its page is rebuilt each time it opens): it opens with
    // that, at the right size, instead of growing once nmcli answers
    property var netCache: ({})
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
    // the welcome tour (apps/Welcome.qml): first start, `monolith welcome`, Settings → About
    property bool welcomeOpen: false
    property string welcomeScreen: ""
    function openWelcome(screen) { open = false; welcomeScreen = target(screen); welcomeOpen = true; }
    function editWidgetsOn(mode, screen) { open = false; wallOpen = false; editScreen = target(screen); editWidgets = mode || "desktop"; }

    // the dock editor, on a screen (Settings → Dock, `monolith dock`)
    property string dockEdit: ""
    function editDock(screen) { open = false; dockEdit = ""; dockEdit = target(screen); }

    // the control center's tab: controls | overview | monitor
    property string ccTab: "controls"
    // Settings opened at a section (keybinds, the island, other pages)
    property string settingsSection: "appearance"
    function openSettings(section, screen) { if (section) settingsSection = section; show("settings", screen); }
    function step(d) { const p = pages[(pages.indexOf(page) + d + pages.length) % pages.length]; if (open) { dir = d > 0 ? 1 : -1; switched(); } page = p; }

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
        target: "welcome"
        function open(): void { hub.openWelcome(); }
        function close(): void { hub.welcomeOpen = false; }
    }
    IpcHandler {
        target: "desktop"
        // the desktop's menu at the middle of the screen you're on (`monolith desktop-menu`)
        function menu(): void { const sc = Quickshell.screens.find(x => x.name === hub.target("")) || Quickshell.screens[0]; hub.openDeskMenu(sc.name, sc.width / 2 - 125, sc.height / 2 - 150, ""); }
        function widget(id: string): void { const sc = Quickshell.screens.find(x => x.name === hub.target("")) || Quickshell.screens[0]; hub.openDeskMenu(sc.name, sc.width / 2 - 125, sc.height / 2 - 150, id); }
    }
    // quick access from a keybind (`quickshell ipc call quick bar right`): on the screen you're on
    property var quickReq: ({ screen: "", edge: "", full: false, n: 0 })
    // something is being dragged onto the quick access tool (a picture onto the drawing pad):
    // it stays out (the pointer isn't "on" it while a drag goes on, so it would put itself away)
    property bool quickHold: false
    // a window just went up into the Overlay layer (the island opening or showing a notification,
    // the notification dropdown): going up puts it on top of the other Overlay windows, the
    // thrown-notification layer too, so swiped cards flew under it. That layer goes back on top.
    property int raised: 0
    function raisedOverlay() { raised++; }
    function quick(edge, full) { quickReq = { screen: target(""), edge: edge || "", full: full, n: quickReq.n + 1 }; }
    IpcHandler {
        target: "quick"
        // the mini bar / the open tool, at the middle of an edge ("" = the first edge in Settings)
        function bar(edge: string): void { hub.quick(edge, false); }
        function open(edge: string): void { hub.quick(edge, true); }
        function hide(): void { hub.quickReq = { screen: "", edge: "hide", full: false, n: hub.quickReq.n + 1 }; }
    }
    IpcHandler {
        target: "widgets"
        // the widget editor: desktop | lock
        function edit(mode: string): void { hub.editWidgetsOn(mode); }
        function done(): void { hub.editWidgets = ""; }
    }
}
