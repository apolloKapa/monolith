pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Desktop mode (Settings → Desktop → Desktop mode; experimental): the shell as a desktop. The bar
// goes to the taskbar's edge (where the dock is, unless you pick another), in its own style,
// the dock sinks into it and becomes its middle (island/TaskStrip.qml: a start button and your
// apps), the launcher gets a rail of buttons down its side, and windows float like on a desktop:
// they open floating, apps draw their own title bars with minimise, maximise and close, and a
// click on an app's taskbar button minimises its window and brings it back. Nothing goes on the
// desktop itself but its widgets.
//
// The bar and the dock aren't changed for it: what it needs (bar.position, bar.style…) stands in
// for your settings while it's on (Store.over), so turning it off leaves them as they were.
// Switching: the menus close, the bar travels to its new edge (Island.qml's own glide, made
// longer while `moving`), then the dock sinks into it (`fuse` 0 → 1); off, the other way round.
Singleton {
    id: desk

    readonly property bool wanted: Store.loaded && Store.raw("desktop.enabled", false) === true
    // the taskbar is up: what it needs stands in for your bar's settings
    property bool on: false
    // the dock inside the taskbar: 0 apart (the dock as it is), 1 one piece (the taskbar's apps)
    property real fuse: 0
    // the bar on its way from one edge to the other (its glide is made longer meanwhile)
    property bool moving: false
    // 0 → 1 over the trip (a bar down a side slides in by it: it has a window of its own)
    property real travelK: 1
    readonly property int travelMs: Theme.animOn ? Theme.ms(760) : 0
    readonly property int fuseMs: Theme.animOn ? Theme.ms(440) : 0

    // where the taskbar goes (Settings): where the dock is, where the bar is, or an edge of its own
    readonly property string barOwnEdge: { const p = String(Store.raw("bar.position", "top")); return edges.indexOf(p) !== -1 ? p : "top"; }
    readonly property string dockOwnEdge: { const p = String(Store.raw("dock.position", "bottom")); return edges.indexOf(p) !== -1 ? p : "bottom"; }
    readonly property var edges: ["top", "bottom", "left", "right"]
    readonly property string edge: {
        const e = String(Store.raw("desktop.edge", "dock"));
        if (edges.indexOf(e) !== -1) return e;
        if (e === "bar") return barOwnEdge;
        return Store.raw("dock.enabled", true) !== false ? dockOwnEdge : "bottom";
    }
    readonly property bool vertical: edge === "left" || edge === "right"
    // the middle of the taskbar, from the screen's edge (a floating bar is off the edge by its margin)
    readonly property real bandMid: Theme.barMargin + size / 2
    // how thick it is
    readonly property real size: Math.max(40, Math.min(72, Number(Store.raw("desktop.height", 48)) || 48))
    // windows open floating; apps draw their own title bars (minimise, maximise, close)
    readonly property bool floating: Store.raw("desktop.floating", true) !== false
    readonly property bool titlebars: Store.raw("desktop.titlebars", true) !== false
    // the apps in the middle, Windows 11 style, or at the start next to the bar's left end
    readonly property string appsAt: Store.raw("desktop.appsAt", "center") === "start" ? "start" : "center"

    // what stands in for your settings while it's on
    readonly property var barDefaults: ({ left: ["cc", "search", "clock", "workspaces"], center: ["media"], right: ["updates", "live", "gaming", "tray", "stats", "notifications", "network", "sound", "battery", "power"] })
    readonly property var overrides: { Store.revision; return computeOverrides(); }
    function computeOverrides() {
        const m = Store.raw("bar.modules", null) || barDefaults;
        const no = k => k !== "taskbar";
        // (the bar's own middle and in-between modules move to the start of its right end: the
        // taskbar's apps have the middle; at the start, they lead the left end)
        const left = (m.outLeft || []).concat(m.left || []).filter(no);
        const moved = (m.leftMid || []).concat(m.center || [], m.midRight || [], m.free || []).filter(no);
        const right = moved.concat(m.right || [], m.outRight || []).filter(no);
        const mods = appsAt === "start"
            ? { left: ["taskbar"], leftMid: [], center: [], midRight: [], right: left.concat(right), free: [], outLeft: [], outRight: [] }
            : { left: left, leftMid: [], center: ["taskbar"], midRight: [], right: right, free: [], outLeft: [], outRight: [] };
        return {
            // (your bar's own style stays: the Frame's round inside corners, an island, a floating
            // bar, pills; only where it is and how tall it is are the taskbar's)
            "bar.position": edge,
            "bar.height": size,
            // (across the screen, a set length: sized to what's in it, a set length shorter than the
            // taskbar needs grew and shrank with every number that changed, the CPU's, the clock's.
            // An island stays an island: fitting what's in it is what it is)
            "bar.lengthMode": String(Store.raw("bar.style", "")) === "island" ? Store.raw("bar.lengthMode", "") : "percent",
            "bar.length": String(Store.raw("bar.style", "")) === "island" ? Store.raw("bar.length", 1) : 1,
            "bar.modules": mods,
            "status.autohide": false,
            "dock.exclusive": false,
            // the start menu: a card just off the taskbar, over its start button (above a bottom
            // taskbar, under a top one, beside a side one), opening the way your menus do
            "menus.barPlaces.search": "off",
            "menus.positions.search": appsAt === "start" ? "top-left" : "top-center",
            "menus.moved.search": null
        };
    }
    // (handed on only when they really change: every saved setting makes them anew, and each new
    // set makes everything that reads a setting look again)
    property string overJson: ""
    onOverridesChanged: if (on) { const j = JSON.stringify(overrides); if (j !== overJson) { overJson = j; Store.over = overrides; } }

    // ── switching ──
    property bool started: false
    // the settings just read (Store.loading) or already there: on from the start, without moving
    function settle() {
        if (started || (!Store.loaded && Object.keys(Store.data).length === 0)) return;
        started = true;
        if (Store.raw("desktop.enabled", false) === true) {
            on = true; fuse = 1; travelK = 1;
            Store.over = computeOverrides();
            overJson = JSON.stringify(Store.over);
            Qt.callLater(() => desk.windowsFor(true));
        }
    }
    Component.onCompleted: settle()
    Connections { target: Store; function onLoading() { desk.settle(); } function onLoadedChanged() { desk.settle(); } }
    // (Hyprland: which kind of config it has is known a moment after the start; its rules wait for it)
    Connections { target: Niri; function onHyprKnownChanged() { if (desk.on && Niri.hyprland) { desk.hyprRules(true); if (desk.titlebars) desk.hyprBars(true); } } }
    onWantedChanged: { if (!started) return; if (wanted) enter(); else leave(); }
    // (Settings was open, where it's switched: open again once it's all moved)
    property string reopen: ""
    function closeMenus() {
        if (HubState.open && HubState.page === "settings") reopen = (HubState.screenName || "") + "|";
        HubState.close();
        HubState.closeDrop();
    }
    function enter() {
        if (on && fuse >= 1 && !outAnim.running && !inAnim.running) return;
        outAnim.stop();
        closeMenus();
        if (!on) { on = true; overJson = JSON.stringify(overrides); Store.over = overrides; travel(); }
        windowsFor(true);
        inAnim.restart();
    }
    function leave() {
        if (!on && !inAnim.running) return;
        inAnim.stop();
        closeMenus();
        windowsFor(false);
        outAnim.restart();
    }
    // the dock out of the taskbar: then the bar goes back to its own edge
    function release() {
        on = false;
        overJson = "";
        Store.over = ({});
        travel();
    }
    function travel() {
        moving = true;
        travelK = 0;
        tripAnim.restart();
    }
    NumberAnimation { id: tripAnim; target: desk; property: "travelK"; from: 0; to: 1; duration: desk.travelMs; easing.type: Easing.InOutCubic; onFinished: desk.arrived() }
    function arrived() {
        moving = false;
        if (reopen !== "" && !outAnim.running && !inAnim.running) {
            const s = reopen.split("|")[0];
            reopen = "";
            reopenLater.screen = s;
            reopenLater.restart();
        }
    }
    Timer { id: reopenLater; property string screen: ""; interval: 120; onTriggered: HubState.show("settings", screen || undefined) }
    // in: the bar on its way, the dock sinks into it as it gets there
    SequentialAnimation {
        id: inAnim
        PauseAnimation { duration: desk.moving ? Math.round(desk.travelMs * 0.8) : 0 }
        NumberAnimation { target: desk; property: "fuse"; to: 1; duration: desk.fuseMs; easing.type: Easing.InOutCubic }
        ScriptAction { script: desk.arrived() }
    }
    // out: the dock rises out of it, then the bar goes
    SequentialAnimation {
        id: outAnim
        NumberAnimation { target: desk; property: "fuse"; to: 0; duration: desk.fuseMs; easing.type: Easing.InOutCubic }
        ScriptAction { script: desk.release() }
    }

    // ── windows ──
    // minimised windows wait out of sight: on Hyprland's special workspace of their own; on niri
    // (which has none, and a named one would come first and push your workspaces' numbers along)
    // on the empty workspace at the end of their screen, noted here. A window counts as minimised
    // while its workspace isn't the one showing: go there, or to it (Alt+Tab), and it's back
    readonly property string minName: "monolith-min"
    property var minIds: ({})
    function isMin(w) {
        if (!w) return false;
        if (Niri.hyprland) return w.workspace_name === "special:" + minName;
        if (minIds[w.id] !== true) return false;
        const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
        return !ws || !ws.is_active;
    }
    function noteMin(id, on) {
        const m = Object.assign({}, minIds);
        if (on) m[id] = true; else delete m[id];
        minIds = m;
    }
    Connections {
        target: Niri
        function onFocusedWindowIdChanged() { if (Niri.focusedWindowId !== null && desk.minIds[Niri.focusedWindowId]) desk.noteMin(Niri.focusedWindowId, false); }
    }
    function addr(w) { return "address:0x" + String(w.id).replace(/^0x/, ""); }
    function hypr(lua, classic) { if (Niri.hyprLua) Hyprland.dispatch(lua); else if (classic) Hyprland.dispatch(classic); }
    function niri(args) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)); }
    function minimize(w) {
        if (!w) return;
        if (Niri.hyprland) hypr('hl.dsp.window.move({ workspace = "special:' + minName + '", follow = false, window = "' + addr(w) + '" })',
                                "movetoworkspacesilent special:" + minName + "," + addr(w));
        else {
            // (niri always keeps an empty workspace at the end of each screen)
            const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
            const list = Niri.workspacesOn(ws ? ws.output : Niri.focusedOutput);
            const last = list.reduce((a, x) => Math.max(a, Number(x.idx) || 0), 0);
            if (last <= 0) return;
            noteMin(w.id, true);
            niri(["move-window-to-workspace", "--window-id", String(w.id), "--focus", "false", String(last)]);
        }
    }
    // back onto the workspace you're on, and focused
    function restore(w) {
        if (!w) return;
        const ws = Niri.workspaces.find(x => x.is_focused) || Niri.workspaces.find(x => x.is_active);
        if (Niri.hyprland) {
            if (ws) hypr("hl.dsp.window.move({ workspace = " + ws.id + ', window = "' + addr(w) + '" })', "movetoworkspace " + ws.id + "," + addr(w));
            hypr('hl.dsp.focus({ window = "' + addr(w) + '" })', "focuswindow " + addr(w));
        } else {
            noteMin(w.id, false);
            if (ws) niri(["move-window-to-workspace", "--window-id", String(w.id), "--focus", "true", ws.name ? String(ws.name) : String(ws.idx)]);
            niri(["focus-window", "--id", String(w.id)]);
        }
    }
    function focus(w) { if (isMin(w)) restore(w); else Niri.action(["focus-window", "--id", String(w.id)]); }
    function maximize(w) {
        if (!w) return;
        if (isMin(w)) restore(w);
        if (Niri.hyprland) {
            if (Niri.hyprLua) Hyprland.dispatch('hl.dsp.window.fullscreen({ mode = "maximized", window = "' + addr(w) + '" })');
            else { Hyprland.dispatch("focuswindow " + addr(w)); Hyprland.dispatch("fullscreen 1"); }
        } else {
            niri(["focus-window", "--id", String(w.id)]);
            niri(["maximize-window-to-edges"]);
        }
    }
    function close(w) { if (w) Niri.action(["close-window", "--id", String(w.id)]); }
    // every minimised window back (desktop mode going off: nothing is left out of sight)
    function restoreAll() { for (const k in Niri.windows) if (isMin(Niri.windows[k])) restore(Niri.windows[k]); }

    // windows open floating, and the ones already open float too (those go back into their
    // tiles when it's off); apps draw their own title bars (niri: no prefer-no-csd; GTK apps get
    // minimise and maximise buttons as well as close). Your own values are noted first
    // (desktop.was.*) and put back when it's off, after a restart too.
    property var floated: []
    function windowsFor(want) {
        if (Niri.hyprland && Niri.hyprKnown) hyprRules(want);
        if (want) {
            if (floating) {
                const ids = [];
                for (const k in Niri.windows) {
                    const w = Niri.windows[k];
                    if (!w || w.is_floating || isMin(w) || (Niri.hyprland && Number(w.workspace_id) < 0)) continue;
                    ids.push(w.id);
                    if (Niri.hyprland) hypr('hl.dsp.window.float({ action = "enable", window = "' + addr(w) + '" })', "setfloating " + addr(w));
                    else niri(["move-window-to-floating", "--id", String(w.id)]);
                }
                floated = floated.concat(ids);
            }
            if (titlebars) bars(true);
        } else {
            restoreAll();
            for (const id of floated) {
                const w = Niri.windows[id];
                if (!w || !w.is_floating) continue;
                if (Niri.hyprland) hypr('hl.dsp.window.float({ action = "disable", window = "' + addr(w) + '" })', "settiled " + addr(w));
                else niri(["move-window-to-tiling", "--id", String(w.id)]);
            }
            floated = [];
            bars(false);
        }
    }
    // the apps' own title bars, on or back to how you had them
    function bars(want) {
        if (gtkButtons.want === want && !gtkButtons.running) gtkButtons.go(); else gtkButtons.want = want;
        if (Niri.hyprland) { hyprBars(want); return; }
        if (want) NiriConf.read(["-|prefer-no-csd"], r => {
            if (r && r["-|prefer-no-csd"] !== null && r["-|prefer-no-csd"] !== undefined) {
                Store.set("desktop.was.noCsd", true);
                NiriConf.flag("-", "prefer-no-csd", false);
            }
        });
        else if (Store.raw("desktop.was.noCsd", false) === true) {
            NiriConf.flag("-", "prefer-no-csd", true);
            Store.unset("desktop.was.noCsd");
        }
    }
    // ── Hyprland: title bars on every window, like a desktop's (scripts/hyprbars.sh builds the
    // hyprbars plugin once; loaded here while Desktop mode is on, in the theme's colours, with
    // minimise, maximise and close on the right, a double click maximising). Apps that draw their
    // own bar (browsers, GNOME apps, Electron apps) are left without one (desktop.noBar).
    // Only into the Hyprland it was built for: another one could refuse it, or worse ──
    readonly property string barsDir: (Quickshell.env("XDG_DATA_HOME") || (Quickshell.env("HOME") + "/.local/share")) + "/monolith/plugins"
    readonly property string barsScript: Qt.resolvedUrl("../scripts/hyprbars.sh").toString().replace("file://", "")
    property string barsFor: ""
    property string hyprCommit: ""
    readonly property string barsState: !Niri.hyprland ? "" : (barsFor === "" ? "none" : (hyprCommit !== "" && barsFor !== hyprCommit ? "old" : "ready"))
    readonly property bool barsReady: barsState === "ready" && hyprCommit !== ""
    FileView { path: desk.barsDir + "/hyprbars.for"; watchChanges: true; printErrors: false; onLoaded: desk.barsFor = text().trim(); onFileChanged: reload(); onLoadFailed: desk.barsFor = "" }
    Process {
        running: Niri.hyprland
        command: ["hyprctl", "version", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { desk.hyprCommit = String(JSON.parse(text).commit || ""); } catch (e) {} } }
    }
    onBarsReadyChanged: if (started && on && titlebars) hyprBars(true)
    // build it, in a terminal so you see it happen
    function buildBars() {
        const cmd = "sh \"$1\"; echo; echo 'You can close this window.'; read -r _";
        Quickshell.execDetached(["sh", "-c", Prefs.terminal + " sh -c '" + cmd.replace(/'/g, "'\\''") + "' _ \"$0\"", barsScript]);
    }
    readonly property var noBarDefault: ["firefox", "librewolf", "zen", "brave-browser", "chromium", "google-chrome", "vivaldi-stable", "org.gnome.*", "discord", "vesktop", "spotify", "code", "codium", "vscodium", "obsidian", "steam"]
    readonly property var noBar: { const v = Store.raw("desktop.noBar", null); return Array.isArray(v) ? v : noBarDefault; }
    function hex(c) { const h = x => ("0" + Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16)).slice(-2); return "rgba(" + h(c.r) + h(c.g) + h(c.b) + h(c.a) + ")"; }
    readonly property string barsLua: {
        const dsp = a => "[[hyprctl dispatch '" + a + "']]";
        const max = 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })';
        const bg = Qt.alpha(Theme.frame, Math.max(0.55, Theme.frame.a));
        const pat = noBar.filter(x => /^[A-Za-z0-9_.*+-]+$/.test(x)).map(x => x.replace(/\./g, "\\.").replace(/\*/g, ".*")).join("|");
        return "MonolithDesk = MonolithDesk or {}; "
            + "hl.config({ plugin = { hyprbars = { enabled = true, bar_height = 34, bar_color = \"" + hex(bg) + "\", "
            // (the buttons' icons are the shell's own, Material Symbols, after your font for the title)
            + "col = { text = \"" + hex(Theme.text) + "\" }, bar_text_size = 12, bar_text_weight = \"medium\", bar_text_font = " + JSON.stringify(Theme.fontFamily + ", Material Symbols Rounded") + ", "
            + "bar_text_align = \"center\", bar_blur = " + (Theme.blur ? "true" : "false") + ", bar_part_of_window = true, bar_precedence_over_border = true, "
            + "bar_padding = 10, bar_button_padding = 6, inactive_button_color = \"" + hex(Qt.alpha(Theme.subtext, 0.35)) + "\", "
            + "on_double_click = " + dsp(max) + " } } }); "
            // (buttons stay until a config reload clears them: added once per reload. Right to left)
            // (round buttons with the shell's icons: close in the theme's red, the others soft)
            + "if not MonolithDesk.barButtons then MonolithDesk.barButtons = true; "
            +   "hl.plugin.hyprbars.add_button({ bg_color = \"" + hex(Qt.alpha(Theme.danger, 0.92)) + "\", fg_color = \"" + hex(Theme.card) + "\", size = 22, icon = \"\ue5cd\", action = " + dsp("hl.dsp.window.close()") + " }); "
            +   "hl.plugin.hyprbars.add_button({ bg_color = \"" + hex(Qt.alpha(Theme.text, 0.12)) + "\", fg_color = \"" + hex(Theme.text) + "\", size = 22, icon = \"\ue3c6\", action = " + dsp(max) + " }); "
            +   "hl.plugin.hyprbars.add_button({ bg_color = \"" + hex(Qt.alpha(Theme.text, 0.12)) + "\", fg_color = \"" + hex(Theme.text) + "\", size = 22, icon = \"\ue15b\", action = " + dsp('hl.dsp.window.move({ workspace = "special:' + minName + '", follow = false })') + " }) end; "
            + (pat === "" ? "" : "if MonolithDesk.noBar then MonolithDesk.noBar:set_enabled(false) end; MonolithDesk.noBar = hl.window_rule({ name = \"monolith-nobar-" + Qt.md5(pat).slice(0, 8) + "\", match = { class = [[(?i)^(" + pat + ")$]] }, [\"hyprbars:no_bar\"] = true })");
    }
    function hyprBars(want) {
        if (!Niri.hyprland || !Niri.hyprLua || !barsReady) return;
        if (want) { barsLoad.running = false; barsLoad.running = true; }
        else Quickshell.execDetached(["hyprctl", "eval", "hl.config({ plugin = { hyprbars = { enabled = false } } })"]);
    }
    // loaded once (it stays loaded: taking a plugin out of a running Hyprland isn't safe), then set up
    Process {
        id: barsLoad
        command: ["sh", "-c", "hyprctl plugin list 2>/dev/null | grep -q hyprbars || hyprctl plugin load \"$1\"", "_", desk.barsDir + "/hyprbars.so"]
        onExited: if (desk.on && desk.titlebars) Quickshell.execDetached(["hyprctl", "eval", desk.barsLua])
    }
    // (the theme or the list changed: set up again)
    onBarsLuaChanged: if (started && on && titlebars && barsReady && Niri.hyprLua) barsLater.restart()
    Timer { id: barsLater; interval: 400; onTriggered: Quickshell.execDetached(["hyprctl", "eval", desk.barsLua]) }
    // (switched in Settings while it's on: at once)
    onTitlebarsChanged: if (started && on) bars(titlebars)
    onFloatingChanged: if (started && on && Niri.hyprland && Niri.hyprKnown) hyprRules(true)
    // Hyprland: a rule that floats every window as it opens, and its minimise requests (an app's
    // own minimise button) send the window to the minimised workspace. Sent at runtime (it isn't
    // in your config); a config reload forgets it, so it's sent again then
    function hyprRules(want) {
        if (Niri.hyprLua) {
            const lua = "MonolithDesk = MonolithDesk or {}; MonolithDesk.on = " + (want ? "true" : "false") + "; "
                + "if MonolithDesk.rule then MonolithDesk.rule:set_enabled(MonolithDesk.on and " + (floating ? "true" : "false") + ") "
                + "elseif MonolithDesk.on and " + (floating ? "true" : "false") + " then MonolithDesk.rule = hl.window_rule({ name = \"monolith-desktop\", match = { class = \".*\" }, float = true }) end; "
                + "if not MonolithDesk.min then MonolithDesk.min = hl.on(\"window.minimize\", function(w, m) "
                +   "if not MonolithDesk.on or not w or m == false or m == 0 then return end; "
                +   "local a = tostring(w.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; "
                +   "hl.dispatch(hl.dsp.window.move({ workspace = \"special:" + minName + "\", follow = false, window = \"address:\" .. a })) end) end; "
                + sizesLua() + " "
                // a window opening: the size its app had last, or, opening as big as the screen
                // (a terminal that asks for no size), a size like a window's, centred
                + "if not MonolithDesk.open then MonolithDesk.open = hl.on(\"window.open\", function(w) "
                +   "if not MonolithDesk.on or not w or not w.floating then return end; "
                +   "local m = w.monitor; local z = w.size; local ww, wh = 0, 0; "
                +   "if type(z) == \"table\" then ww = z[1] or z.x or 0; wh = z[2] or z.y or 0 end; "
                +   "if ww < 300 or wh < 200 then return end; "
                +   "local s = MonolithDesk.sizes and MonolithDesk.sizes[string.lower(tostring(w.class))]; "
                +   "if not s and m and ww >= m.width * 0.8 and wh >= m.height * 0.8 then s = { math.floor(m.width * 0.62), math.floor(m.height * 0.68) } end; "
                +   "if not s then return end; "
                +   "local sw, sh = s[1], s[2]; if m then sw = math.min(sw, m.width - 40); sh = math.min(sh, m.height - 80) end; "
                +   "local a = tostring(w.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; "
                +   "hl.dispatch(hl.dsp.window.resize({ x = sw, y = sh, window = \"address:\" .. a })); "
                +   "hl.dispatch(hl.dsp.window.center({ window = \"address:\" .. a })) end) end";
            Quickshell.execDetached(["hyprctl", "eval", lua]);
        } else if (want && floating) {
            // (the rule's wording changed in 0.53: both are sent, the one it doesn't know is refused)
            Quickshell.execDetached(["sh", "-c", "hyprctl keyword windowrule 'match:class .*, float on'; hyprctl keyword windowrulev2 'float, class:.*'"]);
        } else if (!want) {
            // (rules added at runtime only go with a reload; Monolith's own are sent again after it)
            Quickshell.execDetached(["sh", "-c", "hyprctl reload"]);
        }
    }
    // ── each app's window size, remembered (Store desktop.sizes: app id, lower case → [w, h]) ──
    // noted as windows change (niri says when one is resized; Hyprland's sizes come with its other
    // window events, a focus change among them), so the next window of that app opens that big.
    // Not a maximised or minimised one, not a little one (a dialog)
    readonly property var sizes: Store.raw("desktop.sizes", null) || ({})
    Timer { id: sizeLater; interval: 900; onTriggered: desk.noteSizes() }
    // (Hyprland says nothing when a window is resized: its windows are read again every couple of
    // seconds while windows float here, then their sizes noted. A Hyprland event read them
    // before, often still the old sizes, and a window resized and closed was never noted)
    Timer {
        interval: 2000; repeat: true
        running: desk.on && desk.floating && Niri.hyprland
        onTriggered: { Hyprland.refreshToplevels(); hyprRead.restart(); }
    }
    Timer { id: hyprRead; interval: 350; onTriggered: { Niri.hyprSync(); desk.noteSizes(); } }
    Connections { target: Niri; function onWindowsChanged() { if (desk.on && desk.floating) sizeLater.restart(); } }
    function noteSizes() {
        const cur = Object.assign({}, sizes);
        let changed = false;
        // (the window you're in last: its size wins over another of the same app's)
        const ids = Object.keys(Niri.windows).sort((a, b) => (Niri.windows[a].is_focused ? 1 : 0) - (Niri.windows[b].is_focused ? 1 : 0));
        for (const k of ids) {
            const w = Niri.windows[k];
            if (!w || !w.is_floating || w.is_fullscreen || isMin(w)) continue;
            const sz = w.layout ? w.layout.window_size : null;
            const id = String(w.app_id || "").toLowerCase();
            if (!sz || id === "" || sz[0] < 300 || sz[1] < 200) continue;
            const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
            const scr = ws ? Quickshell.screens.find(x => x.name === ws.output) : null;
            if (scr && (sz[0] >= scr.width * 0.95 || sz[1] >= scr.height * 0.88)) continue;
            const v = [Math.round(sz[0]), Math.round(sz[1])];
            if (!cur[id] || cur[id][0] !== v[0] || cur[id][1] !== v[1]) { cur[id] = v; changed = true; }
        }
        if (changed) Store.set("desktop.sizes", cur);
    }
    function sizesLua() {
        const parts = [];
        for (const id in sizes) {
            const v = sizes[id];
            if (v && v.length === 2) parts.push("[" + JSON.stringify(id) + "] = { " + Math.round(v[0]) + ", " + Math.round(v[1]) + " }");
        }
        return "MonolithDesk.sizes = { " + parts.join(", ") + " };";
    }
    // (Hyprland: the table in it kept up to date)
    onSizesChanged: if (on && Niri.hyprland && Niri.hyprLua && Niri.hyprKnown) Quickshell.execDetached(["hyprctl", "eval", "MonolithDesk = MonolithDesk or {}; " + sizesLua()])
    // (niri: a rule per app, core/NiriShell.qml)
    function regexEscape(t) { return String(t).replace(/[.*+?^${}()|[\]\\]/g, "\\$&"); }
    readonly property string niriSizeRules: {
        let out = "";
        for (const id in sizes) {
            const v = sizes[id];
            if (!v || v.length !== 2 || /["#]/.test(id)) continue;
            out += "window-rule {\n    match app-id=r#\"(?i)^" + regexEscape(id) + "$\"#\n    default-column-width { fixed " + Math.round(v[0]) + "; }\n    default-window-height { fixed " + Math.round(v[1]) + "; }\n}\n";
        }
        return out;
    }

    Connections {
        target: Niri.hyprland ? Hyprland : null
        function onRawEvent(ev) {
            if (ev.name !== "configreloaded") return;
            Niri.hyprStill();
            if (desk.on) {
                desk.hyprRules(true);
                if (desk.titlebars && desk.barsReady) { Quickshell.execDetached(["hyprctl", "eval", "MonolithDesk = MonolithDesk or {}; MonolithDesk.barButtons = nil; MonolithDesk.noBar = nil"]); desk.hyprBars(true); }
            }
        }
    }
    // GTK's title bar buttons (gsettings): minimise, maximise and close while it's on; yours back
    // after (or GNOME's default, if yours weren't noted). One run at a time: switched again while
    // one runs, the newest wish runs after it
    Process {
        id: gtkButtons
        property bool want: false
        property bool ran: false
        onWantChanged: if (!running) go()
        function go() { ran = want; command = ["sh", "-c", 'k="org.gnome.desktop.wm.preferences"; command -v gsettings >/dev/null || exit 0; '
            + 'if [ "$1" = on ]; then cur=$(gsettings get $k button-layout 2>/dev/null); echo "was:$cur"; gsettings set $k button-layout "appmenu:minimize,maximize,close"; '
            + 'elif [ -n "$2" ]; then gsettings set $k button-layout "$2"; else gsettings reset $k button-layout; fi', "_", ran ? "on" : "off",
            String(Store.raw("desktop.was.buttons", "") || "").replace(/^'(.*)'$/, "$1")]; running = true; }
        stdout: SplitParser {
            onRead: line => {
                if (!line.startsWith("was:")) return;
                const v = line.slice(4);
                // (only the first time: on again after a restart, the value now is ours)
                if (v !== "" && v.indexOf("minimize,maximize,close") === -1 && Store.raw("desktop.was.buttons", "") === "") Store.set("desktop.was.buttons", v);
            }
        }
        onExited: { if (!ran) Store.unset("desktop.was.buttons"); if (want !== ran) go(); }
    }
}
