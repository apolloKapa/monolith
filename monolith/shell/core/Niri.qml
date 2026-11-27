pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// The compositor's state: workspaces per output, windows, the focused window and keyboard
// layouts, and its actions. On niri from `niri msg -j event-stream` and `niri msg action`; on
// Hyprland from Quickshell's Hyprland module (its events, hyprctl), in the same shape, so the rest
// of the shell doesn't care which it is. Actions use niri's names; on Hyprland they're turned
// into its dispatchers (action()).
Singleton {
    id: niri

    // running on Hyprland (it sets this for everything it starts)
    readonly property bool hyprland: (Quickshell.env("HYPRLAND_INSTANCE_SIGNATURE") || "") !== ""
    readonly property string compositor: hyprland ? "Hyprland" : "niri"
    // Hyprland's config is Lua (hyprland.lua, then its dispatchers are Lua) or classic: what the
    // running Hyprland loaded (scripts/hypr_files.py reads its log), as a file both may be there
    property bool hyprLua: false
    property bool hyprKnown: false       // (which of the two: known once that's been read)
    Process {
        running: niri.hyprland
        command: ["python3", Qt.resolvedUrl("../scripts/hypr_files.py").toString().replace("file://", ""), "kind"]
        stdout: StdioCollector { onStreamFinished: { niri.hyprLua = text.trim() === "lua"; niri.hyprKnown = true; niri.hyprStill(); } }
    }
    // Monolith's panels (the bar's full-screen layer, the dock, the menus) animate themselves:
    // Hyprland's own open/close animation on top made the bar fly across the screen (a config
    // that animates layers, like another shell's). Off for them, whatever the config includes.
    function hyprStill() {
        if (hyprLua)
            Quickshell.execDetached(["hyprctl", "eval", 'hl.layer_rule({ name = "monolith-still", match = { namespace = "^monolith" }, no_anim = true })']);
        else   // (the rule's wording changed in 0.53: both are sent, the one it doesn't know is refused)
            Quickshell.execDetached(["sh", "-c", "hyprctl keyword layerrule 'noanim, ^(monolith.*)$'; hyprctl keyword layerrule 'match:namespace ^monolith, no_anim on'"]);
    }

    property var workspaces: []          // sorted by output, then idx
    property var windows: ({})           // id -> window
    property var focusedWindowId: null
    property var layouts: []
    property int layoutIndex: 0

    readonly property var focusedWindow: focusedWindowId !== null && windows[focusedWindowId] ? windows[focusedWindowId] : null
    readonly property string focusedTitle: focusedWindow ? (focusedWindow.title || "") : ""
    readonly property string focusedAppId: focusedWindow ? (focusedWindow.app_id || "") : ""
    // niri 26.04 does not report fullscreen (no is_fullscreen): a window covering its whole screen
    // counts (a maximized one leaves the bar's room, so it doesn't). Used for pausing live
    // wallpapers and keeping quick access away, which never happened while it read only the flag.
    readonly property bool focusedFullscreen: !!focusedWindow && (focusedWindow.is_fullscreen === true || covers(focusedWindow))
    function covers(w) {
        const size = w && w.layout ? w.layout.window_size : null;
        if (!size) return false;
        const ws = workspaces.find(x => x.id === w.workspace_id);
        const scr = ws ? Quickshell.screens.find(s => s.name === ws.output) : null;
        return !!scr && size[0] >= scr.width - 1 && size[1] >= scr.height - 1;
    }
    // a fullscreen window is showing on this screen: its shown workspace's active window covers it
    // (the live wallpaper of the other screens keeps playing)
    function fullscreenOn(output) {
        const ws = workspaces.find(x => x.output === output && x.is_active);
        if (!ws) return false;
        const ids = ws.active_window_id !== null && ws.active_window_id !== undefined ? [ws.active_window_id]
            : Object.keys(windows).filter(k => windows[k].workspace_id === ws.id);   // (Hyprland: none is noted)
        return ids.some(k => { const w = windows[k]; return !!w && (w.is_fullscreen === true || covers(w)); });
    }
    // is the box (x, y, w, h, in the screen's own coordinates) hidden behind a window on the
    // workspace showing on this screen? (a desktop widget there then stops animating: unseen, it
    // kept the whole desktop layer redrawing at the screen's refresh rate, wallpaper and all)
    function hides(output, x, y, w, h) {
        if (fullscreenOn(output)) return true;
        const ws = workspaces.find(z => z.output === output && z.is_active);
        if (!ws) return false;
        for (const k in windows) {
            const win = windows[k];
            if (!win || win.workspace_id !== ws.id || !win.layout) continue;
            const pos = win.layout.tile_pos_in_workspace_view, size = win.layout.tile_size;
            if (!pos || !size) continue;
            if (pos[0] <= x + 1 && pos[1] <= y + 1 && pos[0] + size[0] >= x + w - 1 && pos[1] + size[1] >= y + h - 1) return true;
        }
        return false;
    }
    // does a window on the workspace showing on this screen overlap (or touch) the box (x, y, w, h,
    // in the screen's own coordinates)? The bar's and the dock's "dodge windows". A tiled window
    // on niri, which doesn't say where its tile is, counts (tiles fill the screen)
    function overlaps(output, x, y, w, h) {
        const ws = workspaces.find(z => z.output === output && z.is_active);
        if (!ws) return false;
        const t = 4;
        // (Desktop mode's title bars sit on top of a window, outside what Hyprland says is its box:
        // a window dragged up under a bar by its title bar touched it with that, not its body)
        const bar = hyprland && Desk.on && Desk.titlebars && Desk.barsReady ? 34 : 0;
        for (const k in windows) {
            const win = windows[k];
            if (!win || win.workspace_id !== ws.id) continue;
            const L = win.layout;
            const pos = L ? L.tile_pos_in_workspace_view : null;
            if (!pos) { if (!win.is_floating) return true; continue; }
            const sz = L.tile_size || [0, 0];
            if (pos[0] < x + w + t && pos[0] + sz[0] > x - t && pos[1] - bar < y + h + t && pos[1] + sz[1] > y - t) return true;
        }
        return false;
    }
    // the screen with the focused workspace
    readonly property string focusedOutput: { const w = workspaces.find(w => w.is_focused); return w ? (w.output || "") : ""; }
    readonly property string layoutName: layouts.length > layoutIndex ? layouts[layoutIndex] : ""

    function workspacesOn(output) {
        return workspaces.filter(w => w.output === output);
    }

    function focusWorkspace(idx) { action(["focus-workspace", String(idx)]); }
    function action(args) {
        if (!hyprland) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)); return; }
        // niri's action names → Hyprland's dispatchers
        const i = args.indexOf("--id");
        const id = i !== -1 ? String(args[i + 1]) : "";
        const addr = "address:0x" + id.replace(/^0x/, "");
        // a Lua config (hyprland.lua, Hyprland 0.55+): dispatch takes Lua (hl.dsp.*) instead
        if (hyprLua) {
            const ws = /^[0-9]+$/.test(String(args[1])) ? args[1] : JSON.stringify(String(args[1]));
            const lua = ({
                "quit": "hl.dsp.exit()",
                "power-off-monitors": 'hl.dsp.dpms({ action = "disable" })',
                "power-on-monitors": 'hl.dsp.dpms({ action = "enable" })',
                "focus-window": 'hl.dsp.focus({ window = "' + addr + '" })',
                "close-window": id !== "" ? 'hl.dsp.window.close({ window = "' + addr + '" })' : "hl.dsp.window.close()",
                "focus-workspace": "hl.dsp.focus({ workspace = " + ws + " })"
            })[args[0]];
            if (lua) { Hyprland.dispatch(lua); return; }
        }
        switch (args[0]) {
        case "quit": Hyprland.dispatch("exit"); break;
        case "power-off-monitors": Hyprland.dispatch("dpms off"); break;
        case "power-on-monitors": Hyprland.dispatch("dpms on"); break;
        case "focus-window": Hyprland.dispatch("focuswindow " + addr); break;
        case "close-window": Hyprland.dispatch(id !== "" ? "closewindow " + addr : "killactive"); break;
        case "focus-workspace": Hyprland.dispatch("workspace " + args[1]); break;
        case "switch-layout": Quickshell.execDetached(["hyprctl", "switchxkblayout", "all", args[1] === "prev" ? "prev" : "next"]); break;
        // Hyprland has no overview of its own: the hyprexpo plugin's, when it's loaded
        case "toggle-overview": Hyprland.dispatch("hyprexpo:expo toggle"); break;
        default: console.log("Monolith: no Hyprland version of niri's " + args.join(" "));
        }
    }

    function sortWorkspaces(list) {
        return list.slice().sort((a, b) => (a.output === b.output) ? a.idx - b.idx : String(a.output).localeCompare(String(b.output)));
    }

    function handle(ev) {
        if (ev.WorkspacesChanged) {
            workspaces = sortWorkspaces(ev.WorkspacesChanged.workspaces);
        } else if (ev.WorkspaceActivated) {
            const id = ev.WorkspaceActivated.id, focused = ev.WorkspaceActivated.focused;
            const target = workspaces.find(w => w.id === id);
            if (!target) return;
            if (focused && !target.is_focused) Sounds.play("workspace");
            workspaces = workspaces.map(w => {
                const n = Object.assign({}, w);
                if (n.output === target.output) n.is_active = (n.id === id);
                if (focused) n.is_focused = (n.id === id);
                return n;
            });
        } else if (ev.WorkspaceActiveWindowChanged) {
            const e = ev.WorkspaceActiveWindowChanged;
            workspaces = workspaces.map(w => w.id === e.workspace_id ? Object.assign({}, w, { active_window_id: e.active_window_id }) : w);
        } else if (ev.WindowsChanged) {
            const m = {};
            for (const w of ev.WindowsChanged.windows) { m[w.id] = w; if (w.is_focused) focusedWindowId = w.id; }
            windows = m;
        } else if (ev.WindowOpenedOrChanged) {
            const w = ev.WindowOpenedOrChanged.window;
            const m = Object.assign({}, windows);
            m[w.id] = w;
            windows = m;
            if (w.is_focused) focusedWindowId = w.id;
        } else if (ev.WindowLayoutsChanged) {
            // windows moved or resized (the dock's "dodge windows" watches these)
            const m = Object.assign({}, windows);
            for (const c of ev.WindowLayoutsChanged.changes) if (m[c[0]]) m[c[0]] = Object.assign({}, m[c[0]], { layout: c[1] });
            windows = m;
        } else if (ev.WindowClosed) {
            const m = Object.assign({}, windows);
            delete m[ev.WindowClosed.id];
            windows = m;
            if (focusedWindowId === ev.WindowClosed.id) focusedWindowId = null;
        } else if (ev.WindowFocusChanged) {
            focusedWindowId = ev.WindowFocusChanged.id;
        } else if (ev.KeyboardLayoutsChanged) {
            layouts = ev.KeyboardLayoutsChanged.keyboard_layouts.names || [];
            layoutIndex = ev.KeyboardLayoutsChanged.keyboard_layouts.current_idx || 0;
        } else if (ev.KeyboardLayoutSwitched) {
            layoutIndex = ev.KeyboardLayoutSwitched.idx || 0;
        } else if (ev.WindowMinimizeRequested) {
            // a window's own minimise button (niri with Monolith's patch, patches/niri-minimize.patch:
            // niri has no minimising of its own; Desktop mode does it, core/Desk.qml)
            minimizeRequested(ev.WindowMinimizeRequested.id);
        } else if (ev.WindowDragEdge) {
            // a floating window being dragged, the screen edge zone under the pointer (niri with
            // Monolith's patches/niri-drag-edges.patch): Desktop mode tiles it there, core/Desk.qml
            const d = ev.WindowDragEdge;
            dragEdge(d.id, String(d.output || ""), d.zone || "", d.working_area || [0, 0, 0, 0], d.ended === true);
        }
    }
    signal minimizeRequested(var id)
    signal dragEdge(var id, string output, string zone, var area, bool ended)

    // a window has windows on it: for the status line's occupied dots
    function workspaceHasWindows(wsId) {
        for (const k in windows) if (windows[k].workspace_id === wsId) return true;
        return false;
    }

    // ── Hyprland: the same picture, from Quickshell's Hyprland module ──
    // (windows' places and sizes, classes and fullscreen come from hyprctl clients, which the
    // module only asks for when told to: done after each window event)
    function hyprSync() {
        if (!hyprland) return;
        const ws = Hyprland.workspaces.values.filter(w => w.id > 0).map(w => ({
            id: w.id, idx: w.id, name: w.name, output: w.monitor ? w.monitor.name : "",
            is_active: !!(w.monitor && w.monitor.activeWorkspace === w),
            is_focused: Hyprland.focusedWorkspace === w, active_window_id: null }));
        workspaces = sortWorkspaces(ws);
        const m = {};
        let fid = null;
        for (const t of Hyprland.toplevels.values) {
            // (only windows on a workspace: games under Proton and Steam leave dozens of hidden
            // helper windows ("Default IME", "Input", rundll32, steamwebhelper) that Hyprland
            // never maps or lists, but Quickshell's list still has; Alt+Tab showed them all)
            if (!t.workspace) continue;
            const o = t.lastIpcObject || {};
            const mon = t.monitor;
            const at = o.at, size = o.size;
            const w = {
                id: String(t.address), title: t.title || "",
                app_id: o["class"] || (t.wayland ? t.wayland.appId : "") || "",
                workspace_id: t.workspace ? t.workspace.id : null,
                workspace_name: t.workspace ? String(t.workspace.name || "") : "",
                is_focused: t.activated === true, is_floating: o.floating === true,
                // (Hyprland: 0 none, 1 maximised, 2 fullscreen. Counting a maximised window as
                // fullscreen put the live wallpaper to sleep whenever one was open)
                is_fullscreen: Number(o.fullscreen || 0) >= 2, pid: o.pid || 0,
                // Hyprland's own most-recently-used order (0 = focused last); Alt+Tab starts from it
                focus_history: typeof o.focusHistoryID === "number" ? o.focusHistoryID : 1000000,
                // where it is on its screen (the dock's "dodge windows" reads this, as on niri)
                // (window_size: what covers() reads, so a borderless window the size of the screen
                // counts as fullscreen, as on niri)
                layout: at && size ? { tile_pos_in_workspace_view: [at[0] - (mon ? mon.x : 0), at[1] - (mon ? mon.y : 0)], tile_size: size, window_size: size } : null
            };
            m[w.id] = w;
            if (w.is_focused) fid = w.id;
        }
        // (only when something did change: read often while windows are dragged, see below, a new
        // list each time made everything that looks at windows look again)
        const j = JSON.stringify(m);
        if (j !== lastSync) { lastSync = j; windows = m; }
        if (focusedWindowId !== fid) focusedWindowId = fid;
    }
    property string lastSync: ""
    // something dodges windows (the bar, a mini bar, the dock): Hyprland says where a window is
    // only once it's dropped, so while one is dodging the windows are read ten times a second,
    // and the bar gets out of the way the moment a window is dragged over it
    readonly property bool dodging: hyprland && (Theme.barShow === "dodge" || String(Store.get("dock.show", "")) === "dodge"
        || (Store.get("bar.minis", []) || []).some(m => m && (m.show === "dodge" || ((!m.show || m.show === "bar") && Theme.barShow === "dodge"))))
    Timer { interval: 100; repeat: true; running: niri.dodging; onTriggered: { Hyprland.refreshToplevels(); hyprLater.restart(); } }
    // many events come together (a window opening is several): one sync for all of them
    Timer { id: hyprLater; interval: 40; onTriggered: niri.hyprSync() }
    Connections {
        target: niri.hyprland ? Hyprland : null
        function onRawEvent(ev) {
            const name = ev.name;
            if (name === "activelayout") {
                // "keyboard name,layout name"
                const l = String(ev.data).split(",").slice(1).join(",");
                niri.layouts = [l]; niri.layoutIndex = 0;
                return;
            }
            if (/window|move|fullscreen|float|close|open|urgent/.test(name)) Hyprland.refreshToplevels();
            hyprLater.restart();
        }
        function onFocusedWorkspaceChanged() { hyprLater.restart(); }
        function onActiveToplevelChanged() { hyprLater.restart(); }
    }
    // the keyboard layout to start with (later changes come as events)
    Process {
        id: hyprKeymap
        running: niri.hyprland
        command: ["hyprctl", "devices", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const kb = (JSON.parse(text).keyboards || []);
                    const main = kb.find(k => k.main) || kb[0];
                    if (main && main.active_keymap) { niri.layouts = [main.active_keymap]; niri.layoutIndex = 0; }
                } catch (e) {}
            }
        }
    }
    Component.onCompleted: if (hyprland) { Hyprland.refreshToplevels(); hyprLater.restart(); }

    Process {
        id: stream
        running: !niri.hyprland
        command: ["niri", "msg", "-j", "event-stream"]
        stdout: SplitParser {
            onRead: line => { try { niri.handle(JSON.parse(line)); } catch (e) {} }
        }
        // niri restarted or the stream dropped: reconnect
        onExited: restart.start()
    }
    Timer { id: restart; interval: 1000; onTriggered: if (!niri.hyprland) stream.running = true }
}
