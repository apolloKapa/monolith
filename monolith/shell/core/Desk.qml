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

    // experimental features (Settings → Updates & about): Desktop mode is one. Never set, it's on
    // for whoever had Desktop mode on already, so nothing goes away under them
    readonly property bool experimental: Store.raw("experimental.enabled", Store.raw("desktop.enabled", false) === true) === true
    readonly property bool wanted: Store.loaded && experimental && Store.raw("desktop.enabled", false) === true
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
    readonly property string lengthMode: { const v = String(Store.raw("desktop.lengthMode", "")); return ["fit", "percent", "px"].indexOf(v) !== -1 ? v : (String(Store.raw("bar.style", "")) === "island" ? "fit" : "percent"); }
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
    // (only what the taskbar can't do without: everything else of your bar's works as it does
    // anywhere, its style, its length (the apps fit in it), auto-hide…. Bar → Position and Height
    // set the taskbar's own while it's on, desktop.edge and desktop.height)
    readonly property var overrides: { Store.revision; return computeOverrides(); }
    function computeOverrides() {
        const m = Store.raw("bar.modules", null) || barDefaults;
        // the start button and the apps: where you put them in the bar, else the taskbar's middle.
        // Always in the taskbar: one in a mini bar is left out of it meanwhile (island/MiniBars.qml),
        // like the dock going into the taskbar. A mini bar with the apps kept your whole bar as it
        // was (no start button, no apps), then the apps in their own pill beside the taskbar
        const inBar = k => Object.keys(m).some(z => Array.isArray(m[z]) && m[z].indexOf(k) !== -1);
        const wanted = ["start", "taskbar"].filter(k => !inBar(k));
        const own = { left: [], leftMid: [], center: [], midRight: [], right: [], free: [], outLeft: [], outRight: [] };
        for (const z in own) own[z] = (m[z] || []).slice();
        // (in your bar: your layout as it is, the other one next to it if it's nowhere)
        if (inBar("start") || inBar("taskbar")) {
            for (const z in own) {
                if (wanted.indexOf("taskbar") !== -1 && own[z].indexOf("start") !== -1) own[z].splice(own[z].indexOf("start") + 1, 0, "taskbar");
                if (wanted.indexOf("start") !== -1 && own[z].indexOf("taskbar") !== -1) own[z].splice(own[z].indexOf("taskbar"), 0, "start");
            }
            return base(own);
        }
        const no = k => k !== "taskbar" && k !== "start";
        // (the bar's own middle and in-between modules move to the start of its right end: the
        // taskbar's apps have the middle; at the start, they lead the left end)
        const left = (m.outLeft || []).concat(m.left || []).filter(no);
        const moved = (m.leftMid || []).concat(m.center || [], m.midRight || [], m.free || []).filter(no);
        const right = moved.concat(m.right || [], m.outRight || []).filter(no);
        const mods = appsAt === "start"
            ? { left: wanted, leftMid: [], center: [], midRight: [], right: left.concat(right), free: [], outLeft: [], outRight: [] }
            : { left: left, leftMid: [], center: wanted, midRight: [], right: right, free: [], outLeft: [], outRight: [] };
        return base(mods);
    }
    function base(mods) {
        return {
            // (your bar's own style stays: the Frame's round inside corners, an island, a floating
            // bar, pills; only where it is and how tall it is are the taskbar's)
            "bar.position": edge,
            "bar.height": size,
            // the taskbar's own length (Bar → Length sets it while Desktop mode is on): across the
            // screen unless you say otherwise. Your bar's (1230 px, say) left the apps no room and
            // they came out tiny. An island fits what's in it, unless you give it a length here
            "bar.lengthMode": lengthMode,
            "bar.length": Math.max(0.2, Math.min(1, Number(Store.raw("desktop.length", 1)) || 1)),
            "bar.lengthPx": Math.max(200, Number(Store.raw("desktop.lengthPx", 1600)) || 1600),
            "bar.modules": mods,
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
        if (Store.raw("desktop.enabled", false) === true && experimental) {
            on = true; fuse = 1; travelK = 1;
            Store.over = computeOverrides();
            overJson = JSON.stringify(Store.over);
            Qt.callLater(() => desk.windowsFor(true));
            // (niri tells the shell its windows a moment after the start: floated then, they
            // stayed in their tiles, none being known yet)
            if (!Niri.hyprland) floatPending = true;
        }
    }
    property bool floatPending: false
    Connections {
        target: Niri
        function onWindowsChanged() {
            if (!desk.floatPending || Niri.hyprland || Object.keys(Niri.windows).length === 0) return;
            desk.floatPending = false;
            if (desk.on && desk.floating) desk.windowsFor(true);
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
    // the workspace you were on last (not one where minimised windows wait): where a minimised
    // window comes back to when something else than the taskbar brings it up
    property var lastWs: null
    function noteWs() {
        const f = Niri.workspaces.find(x => x.is_focused);
        if (!f) return;
        for (const id in minIds) { const w = Niri.windows[id]; if (w && w.workspace_id === f.id) return; }
        lastWs = { id: f.id, idx: f.idx, name: f.name || "", output: f.output };
    }
    Connections {
        target: Niri
        function onWorkspacesChanged() { if (!Niri.hyprland) desk.noteWs(); }
        // niri: a minimised window focused some other way (Alt+Tab, a notification): niri went over
        // to the empty workspace it waits on, and it stayed there. It comes back onto the workspace
        // you were on, with you
        function onFocusedWindowIdChanged() {
            const id = Niri.focusedWindowId;
            if (id === null || !desk.minIds[id]) return;
            desk.noteMin(id, false);
            const back = desk.lastWs;
            if (Niri.hyprland || !back || !Niri.workspaces.find(x => x.id === back.id)) return;
            const w = Niri.windows[id], at = w ? Niri.workspaces.find(x => x.id === w.workspace_id) : null;
            if (at && at.output !== back.output) desk.niri(["move-window-to-monitor", back.output]);
            desk.niri(["move-window-to-workspace", "--window-id", String(id), "--focus", "true", back.name ? back.name : String(back.idx)]);
            desk.niri(["focus-window", "--id", String(id)]);
        }
    }
    function addr(w) { return "address:0x" + String(w.id).replace(/^0x/, ""); }
    function hypr(lua, classic) { if (Niri.hyprLua) Hyprland.dispatch(lua); else if (classic) Hyprland.dispatch(classic); }
    function niri(args) { Quickshell.execDetached(["niri", "msg", "action"].concat(args)); }
    // (niri, patched: a window's own minimise button. With Desktop mode off too: the dock, Alt+Tab
    // or going to it bring it back, see onFocusedWindowIdChanged)
    Connections { target: Niri; function onMinimizeRequested(id) { if (!Niri.hyprland) desk.minimize(Niri.windows[id]); } }
    function minimize(w) {
        if (!w) return;
        if (Niri.hyprland) {
            if (Niri.hyprLua) Quickshell.execDetached(["hyprctl", "eval", 'if MonolithDesk and MonolithDesk.minimizeWin then MonolithDesk.minimizeWin("' + addr(w) + '") else hl.dispatch(hl.dsp.window.move({ workspace = "special:' + minName + '", follow = false, window = "' + addr(w) + '" })) end'])
            else Hyprland.dispatch("movetoworkspacesilent special:" + minName + "," + addr(w));
        }
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
                    else {
                        // (niri keeps a tile's size as it floats: a full-height column covered the
                        // taskbar. The size you last gave the app, or two thirds of the screen)
                        const s = sizes[String(w.app_id || "").toLowerCase()];
                        niri(["move-window-to-floating", "--id", String(w.id)]);
                        niri(["set-window-width", "--id", String(w.id), s ? String(Math.round(s[0])) : "66%"]);
                        niri(["set-window-height", "--id", String(w.id), s ? String(Math.round(s[1])) : "70%"]);
                        centerLater(w.id);
                    }
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
    // kitty's own title bar (niri draws none, and Monolith's kitty.conf hides kitty's): a file of
    // Monolith's, monolith-desktop.conf, included once at the end of your kitty.conf, says
    // "hide_window_decorations no" while Desktop mode is on, and nothing otherwise. Your kitty.conf
    // itself is left as it is. Kitty takes it in its windows opened from then on
    function kittyBars(want) {
        Quickshell.execDetached(["sh", "-c",
            'd="${XDG_CONFIG_HOME:-$HOME/.config}/kitty"; [ -f "$d/kitty.conf" ] || exit 0; '
            + 'printf "%s\\n" "# Written by Monolith: Desktop mode on niri turns kitty\'s own title bar on here (niri draws none). Changes here are replaced." > "$d/monolith-desktop.conf"; '
            + '[ "$1" = on ] && printf "hide_window_decorations no\\n" >> "$d/monolith-desktop.conf"; '
            + 'grep -q "include monolith-desktop.conf" "$d/kitty.conf" || printf "\\n# Monolith Desktop mode (niri): kitty\'s title bar\\ninclude monolith-desktop.conf\\n" >> "$d/kitty.conf"',
            "_", want ? "on" : "off"]);
    }
    // the apps' own title bars, on or back to how you had them
    function bars(want) {
        if (gtkButtons.want === want && !gtkButtons.running) gtkButtons.go(); else gtkButtons.want = want;
        // (on Hyprland its title bars plugin draws one: kitty's own would make two)
        kittyBars(want && !Niri.hyprland);
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
    // (what the build can do beyond the plugin's own: "double-click", the double click's speed)
    property string barsFeatures: ""
    FileView { path: desk.barsDir + "/hyprbars.features"; watchChanges: true; printErrors: false; onLoaded: desk.barsFeatures = text().trim(); onFileChanged: reload(); onLoadFailed: desk.barsFeatures = "" }
    readonly property bool barsDoubleClick: barsFeatures.indexOf("double-click") !== -1
    // the longest time between the two clicks of a double click on a title bar (Settings)
    readonly property int doubleClickMs: Math.max(100, Math.min(700, Number(Store.raw("desktop.doubleClickMs", 180)) || 180))
    // (and whether the build Hyprland has loaded knows it: a new build is only loaded when Hyprland
    // starts, and the one before refuses the setting, as a config error)
    property bool barsDoubleClickLoaded: false
    Process {
        id: askDouble
        command: ["hyprctl", "getoption", "plugin:hyprbars:double_click_ms"]
        stdout: StdioCollector { onStreamFinished: desk.barsDoubleClickLoaded = text.indexOf("int:") !== -1 }
    }
    property string hyprCommit: ""
    readonly property string barsState: !Niri.hyprland ? "" : (barsFor === "" ? "none" : (hyprCommit !== "" && barsFor !== hyprCommit ? "old" : "ready"))
    readonly property bool barsReady: barsState === "ready" && hyprCommit !== ""
    FileView { path: desk.barsDir + "/hyprbars.for"; watchChanges: true; printErrors: false; onLoaded: desk.barsFor = text().trim(); onFileChanged: reload(); onLoadFailed: desk.barsFor = "" }
    Process {
        running: Niri.hyprland
        command: ["hyprctl", "version", "-j"]
        stdout: StdioCollector { onStreamFinished: { try { desk.hyprCommit = String(JSON.parse(text).commit || ""); } catch (e) {} } }
    }
    onBarsReadyChanged: { if (started && on && titlebars) hyprBars(true); if (started && on && Niri.hyprland && Niri.hyprKnown) hyprRules(true); }
    // build it, in a terminal so you see it happen
    function buildBars() {
        const cmd = "sh \"$1\"; echo; echo 'You can close this window.'; read -r _";
        Quickshell.execDetached(["sh", "-c", Prefs.terminal + " sh -c '" + cmd.replace(/'/g, "'\\''") + "' _ \"$0\"", barsScript]);
    }
    // (Spotify isn't here: on Linux it draws no window buttons of its own, and without ours it had none)
    readonly property var noBarDefault: ["firefox", "librewolf", "zen", "brave-browser", "chromium", "google-chrome", "vivaldi-stable", "org.gnome.*", "*discord*", "*vesktop*", "code", "codium", "*vscodium*", "obsidian", "steam"]
    // (Vesktop with its system title bar, nativeTitleBar in its settings, gets ours: with Discord's
    // own, double-clicking it lost track of whether it was maximised)
    readonly property var noBar: {
        const v = Store.raw("desktop.noBar", null);
        const l = Array.isArray(v) ? v : noBarDefault;
        return vesktopNative ? l.filter(x => x.toLowerCase().indexOf("vesktop") === -1) : l;
    }
    property bool vesktopNative: false
    function readVesktop(t) { try { if (t) vesktopNative = JSON.parse(t).nativeTitleBar === true; } catch (e) {} }
    FileView { path: Quickshell.env("HOME") + "/.config/vesktop/settings.json"; watchChanges: true; printErrors: false; onLoaded: desk.readVesktop(text()); onFileChanged: reload() }
    FileView { path: Quickshell.env("HOME") + "/.var/app/dev.vencord.Vesktop/config/vesktop/settings.json"; watchChanges: true; printErrors: false; onLoaded: desk.readVesktop(text()); onFileChanged: reload() }
    function hex(c) { const h = x => ("0" + Math.round(Math.max(0, Math.min(1, x)) * 255).toString(16)).slice(-2); return "rgba(" + h(c.r) + h(c.g) + h(c.b) + h(c.a) + ")"; }
    readonly property string barsLua: {
        // (the buttons and the double click act on the window whose bar is under the pointer,
        // MonolithDesk.barAct below: "the window you're in" was a moment late, and with focus
        // following the mouse it was sometimes another one, or none, and the button did nothing)
        const act = k => "[[hyprctl eval 'MonolithDesk.barAct(\"" + k + "\")']]";
        const bg = Qt.alpha(Theme.frame, Math.max(0.55, Theme.frame.a));
        const pat = noBar.filter(x => /^[A-Za-z0-9_.*+-]+$/.test(x)).map(x => x.replace(/\./g, "\\.").replace(/\*/g, ".*")).join("|");
        return "MonolithDesk = MonolithDesk or {}; "
            + "hl.config({ plugin = { hyprbars = { enabled = true, bar_height = 34, bar_color = \"" + hex(bg) + "\", "
            // (the buttons' icons are the shell's own, Material Symbols, after your font for the title)
            + "col = { text = \"" + hex(Theme.text) + "\" }, bar_text_size = 12, bar_text_weight = \"medium\", bar_text_font = " + JSON.stringify(Theme.fontFamily + ", Material Symbols Rounded") + ", "
            + "bar_text_align = \"center\", bar_blur = " + (Theme.blur ? "true" : "false") + ", bar_part_of_window = true, bar_precedence_over_border = true, "
            + "bar_padding = 10, bar_button_padding = 6, inactive_button_color = \"" + hex(Qt.alpha(Theme.subtext, 0.35)) + "\", "
            + "on_double_click = " + act("max") + " } } }); "
            // (only to a build that has the setting: an older one reports it as a config error,
            // Hyprland's red banner over the screen)
            + "if hl.get_config(\"plugin:hyprbars:double_click_ms\") ~= nil then hl.config({ plugin = { hyprbars = { double_click_ms = " + doubleClickMs + " } } }) end; "
            + "MonolithDesk.barAct = function(kind) "
            +   "local c = hl.get_cursor_pos(); if not c then return end; local cx, cy = c.x or c[1], c.y or c[2]; "
            +   "local bh = tonumber(hl.get_config(\"plugin:hyprbars:bar_height\")) or 34; "
            +   "local function xy(v) if type(v) == \"table\" then return (v.x or v[1] or 0), (v.y or v[2] or 0) end return 0, 0 end; "
            +   "local function hit(w) if not w then return false end; local ax, ay = xy(w.at); local zw, zh = xy(w.size); return cx >= ax and cx <= ax + zw and cy >= ay - bh - 6 and cy <= ay + zh end; "
            +   "local win = hl.get_active_window(); "
            +   "if not hit(win) then win = nil; for _, w in ipairs(hl.get_windows()) do if w.mapped and w.visible and hit(w) then win = w; break end end end; "
            +   "if not win then return end; "
            +   "local a = tostring(win.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; local s = \"address:\" .. a; "
            +   "if kind == \"close\" then hl.dispatch(hl.dsp.window.close({ window = s })) "
            +   "elseif kind == \"max\" then hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"toggle\", window = s })) "
            +   "elseif kind == \"min\" then MonolithDesk.minimizeWin(s) end "
            + "end; "
            // (buttons stay until a config reload clears them: added once per reload. Right to left)
            // (round buttons with the shell's icons: close in the theme's red, the others soft)
            // (a config reload clears them: a hook in Hyprland notes that, once per reload. Noted
            // from the shell, a reload reported twice put every button there twice)
            + "if not MonolithDesk.reloadHook then MonolithDesk.reloadHook = hl.on(\"config.reloaded\", function() MonolithDesk.barButtons = nil end) end; "
            + "if MonolithDesk.barButtons ~= 2 then MonolithDesk.barButtons = 2; "
            +   "hl.plugin.hyprbars.add_button({ bg_color = \"" + hex(Qt.alpha(Theme.danger, 0.92)) + "\", fg_color = \"" + hex(Theme.card) + "\", size = 22, icon = \"\ue5cd\", action = " + act("close") + " }); "
            +   "hl.plugin.hyprbars.add_button({ bg_color = \"" + hex(Qt.alpha(Theme.text, 0.12)) + "\", fg_color = \"" + hex(Theme.text) + "\", size = 22, icon = \"\ue3c6\", action = " + act("max") + " }); "
            +   "hl.plugin.hyprbars.add_button({ bg_color = \"" + hex(Qt.alpha(Theme.text, 0.12)) + "\", fg_color = \"" + hex(Theme.text) + "\", size = 22, icon = \"\ue15b\", action = " + act("min") + " }) end; "
            + (pat === "" ? "if MonolithDesk.noBar then MonolithDesk.noBar:set_enabled(false); MonolithDesk.noBar = nil end" : "if MonolithDesk.noBar then MonolithDesk.noBar:set_enabled(false) end; MonolithDesk.noBar = hl.window_rule({ name = \"monolith-nobar-" + Qt.md5(pat).slice(0, 8) + "\", match = { class = [[(?i)^(" + pat + ")$]] }, [\"hyprbars:no_bar\"] = true })");
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
        onExited: { if (desk.on && desk.titlebars) Quickshell.execDetached(["hyprctl", "eval", desk.barsLua]); askDouble.running = true; }
    }
    // (the theme or the list changed: set up again)
    onBarsLuaChanged: if (started && on && titlebars && barsReady && Niri.hyprLua) barsLater.restart()
    Timer { id: barsLater; interval: 400; onTriggered: Quickshell.execDetached(["hyprctl", "eval", desk.barsLua]) }
    // (switched in Settings while it's on: at once)
    onFloatingChanged: if (started && on && Niri.hyprland && Niri.hyprKnown) hyprRules(true)
    // (the window menu needs our title bars: told again when they're ready or switched)
    onTitlebarsChanged: { if (started && on) bars(titlebars); if (started && on && Niri.hyprland && Niri.hyprKnown) hyprRules(true); }
    // Hyprland: a rule that floats every window as it opens, and its minimise requests (an app's
    // own minimise button) send the window to the minimised workspace. Sent at runtime (it isn't
    // in your config); a config reload forgets it, so it's sent again then
    function hyprRules(want) {
        if (Niri.hyprLua) {
            // (hooks made by an older version are taken out first, so the ones below replace them)
            const lua = "MonolithDesk = MonolithDesk or {}; "
                // (dragging a window: from where you took hold of it. Hyprland's drag_center_window
                // put the pointer in its middle; yours back when Desktop mode is off)
                + (want ? "if MonolithDesk.dragWas == nil then MonolithDesk.dragWas = hl.get_config(\"binds.drag_center_window\") end; hl.config({ binds = { drag_center_window = false } }); "
                        : "if MonolithDesk.dragWas ~= nil then hl.config({ binds = { drag_center_window = MonolithDesk.dragWas } }); MonolithDesk.dragWas = nil end; ")
                + "if MonolithDesk.hv ~= 9 then for _, k in ipairs({ \"min\", \"open\", \"reloadHook\", \"spHook\", \"fsHook\" }) do if MonolithDesk[k] then pcall(function() MonolithDesk[k]:remove() end); MonolithDesk[k] = nil end end; MonolithDesk.hv = 9 end; "
                // out of fullscreen, back to how it was before: Hyprland tells every app it's maximised
                // (so they draw no title bars of their own) and takes any maximise or unmaximise an app
                // asks for as "the other way round". Electron asks for one as it leaves fullscreen, so
                // Discord out of a fullscreen stream (Escape, or a window opening over it: the
                // screenshare picker) was put back maximised and at once shrunk to its floating size,
                // its page still laid out for the big one. For a moment after, it goes back to maximised if it was
                // (or if it's not known, or it's maximised meanwhile: the app's own button). It never
                // shrinks a window: that undid you maximising it straight after
                + "if not MonolithDesk.fsHook then MonolithDesk.fsMode = { }; MonolithDesk.fsBack = { }; "
                +   "for _, v in ipairs(hl.get_windows() or { }) do local a = tostring(v.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; MonolithDesk.fsMode[a] = v.fullscreen or 0 end; "
                +   "MonolithDesk.fsFix = function(a) local b = MonolithDesk.fsBack[a]; if not b then return end; local s = \"address:\" .. a; local v = hl.get_window(s); "
                +     "if not v then MonolithDesk.fsBack[a] = nil; return end; local m = v.fullscreen or 0; if b.want ~= 1 or m ~= 0 then return end; "
                +     "hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\", window = s })) end; "
                +   "MonolithDesk.fsHook = hl.on(\"window.fullscreen\", function(w) "
                +     "if not MonolithDesk.on or not w then return end; "
                +     "local a = tostring(w.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; "
                +     "local m = w.fullscreen or 0; local was = MonolithDesk.fsMode[a] or 0; MonolithDesk.fsMode[a] = m; "
                +     "if m >= 2 then if was < 2 then MonolithDesk.fsBack[a] = { want = was } end; return end; "
                +     "if was >= 2 and not MonolithDesk.fsBack[a] then MonolithDesk.fsBack[a] = { want = 1 } end; "
                +     "local b = MonolithDesk.fsBack[a]; if not b then return end; if m == 1 then b.want = 1 end; "
                +     "if was >= 2 then b.out = true; b.n = (b.n or 0) + 1; local n = b.n; "
                +       "hl.timer(function() MonolithDesk.fsFix(a) end, { timeout = 120, type = \"oneshot\" }); "
                +       "hl.timer(function() MonolithDesk.fsFix(a) end, { timeout = 700, type = \"oneshot\" }); "
                +       "hl.timer(function() if MonolithDesk.fsBack[a] and MonolithDesk.fsBack[a].n == n then MonolithDesk.fsFix(a); MonolithDesk.fsBack[a] = nil end end, { timeout = 1600, type = \"oneshot\" }) "
                // (straight away, inside the same step: Hyprland tells the app its new size only once it's
                // done, so it's never told the small one. Put right 0.1 s later, it showed small first)
                +     "end; "
                +     "if m == 0 and b.out and b.want == 1 then hl.dispatch(hl.dsp.window.fullscreen({ mode = \"maximized\", action = \"set\", window = \"address:\" .. a })) end "
                +     "end) end; "
                // minimising: noted for a moment (see the hook below), then off to the minimised workspace
                + "MonolithDesk.minimizeWin = function(s) MonolithDesk.justMin = true; "
                +   "hl.dispatch(hl.dsp.window.move({ workspace = \"special:" + minName + "\", follow = false, window = s })); "
                +   "hl.timer(function() MonolithDesk.justMin = false end, { timeout = 700, type = \"oneshot\" }) end; "
                // the minimised workspace never shows: Hyprland opened it over the screen when the last
                // window of a workspace was minimised, or a minimised one was focused (Alt+Tab), and its
                // dimmed layer took every click behind it. Hidden at once; a window being focused comes back
                + "if not MonolithDesk.spHook then MonolithDesk.spHook = hl.on(\"workspace.special_active\", function() "
                +   "for _, m in ipairs(hl.get_monitors()) do local sp = hl.get_active_special_workspace(m); "
                +     "if sp and sp.name == \"special:" + minName + "\" then "
                +       "local w = hl.get_active_window(); local ws = m.active_workspace; "
                +       "hl.dispatch(hl.dsp.workspace.toggle_special(\"" + minName + "\")); "
                +       "if not MonolithDesk.justMin and w and w.workspace and w.workspace.name == \"special:" + minName + "\" and ws then "
                +         "local a = tostring(w.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; "
                +         "hl.dispatch(hl.dsp.window.move({ workspace = ws.id, window = \"address:\" .. a })); hl.dispatch(hl.dsp.focus({ window = \"address:\" .. a })) end "
                +     "end end end) end; "
                + "MonolithDesk.on = " + (want ? "true" : "false") + "; "
                + "if MonolithDesk.rule then MonolithDesk.rule:set_enabled(MonolithDesk.on and " + (floating ? "true" : "false") + ") "
                + "elseif MonolithDesk.on and " + (floating ? "true" : "false") + " then MonolithDesk.rule = hl.window_rule({ name = \"monolith-desktop\", match = { class = \".*\" }, float = true }) end; "
                + "if not MonolithDesk.min then MonolithDesk.min = hl.on(\"window.minimize\", function(w, m) "
                // (only a request that really says minimise: one saying "not minimised" (an app
                // bringing itself back, Discord as it starts sharing its screen) minimised it)
                +   "if not MonolithDesk.on or not w or not (m == true or m == 1) then return end; "
                +   "local a = tostring(w.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; "
                +   "MonolithDesk.minimizeWin(\"address:\" .. a) end) end; "
                + sizesLua() + " "
                // a window opening: the size its app had last, or, opening as big as the screen
                // (a terminal that asks for no size), a size like a window's, centred
                + "if not MonolithDesk.open then MonolithDesk.open = hl.on(\"window.open\", function(w) "
                +   "if not MonolithDesk.on or not w or not w.floating then return end; "
                +   "local m = w.monitor; local z = w.size; local ww, wh = 0, 0; "
                +   "if type(z) == \"table\" then ww = z[1] or z.x or 0; wh = z[2] or z.y or 0 end; "
                +   "if ww < 300 or wh < 200 then return end; "
                // (not a window an open one opened, a screen-share picker or a dialog: those come
                // from the same process, and made as big as its main one they didn't work. Another
                // window of the app on its own, a second terminal, gets the size too)
                +   "local cls = string.lower(tostring(w.class)); local me = tostring(w.address); "
                +   "for _, o in ipairs(hl.get_windows()) do if tostring(o.address) ~= me and string.lower(tostring(o.class)) == cls and o.pid == w.pid then return end end; "
                +   "local s = MonolithDesk.sizes and MonolithDesk.sizes[string.lower(tostring(w.class))]; "
                +   "if not s and m and ww >= m.width * 0.8 and wh >= m.height * 0.8 then s = { math.floor(m.width * 0.62), math.floor(m.height * 0.68) } end; "
                +   "if not s then return end; "
                +   "local sw, sh = s[1], s[2]; if m then sw = math.min(sw, m.width - 40); sh = math.min(sh, m.height - 80) end; "
                +   "local a = tostring(w.address); if a:sub(1, 2) ~= \"0x\" then a = \"0x\" .. a end; "
                +   "hl.dispatch(hl.dsp.window.resize({ x = sw, y = sh, window = \"address:\" .. a })); "
                +   "hl.dispatch(hl.dsp.window.center({ window = \"address:\" .. a })) end) end"
                + (want ? kdeLua() : "");
            Quickshell.execDetached(["hyprctl", "eval", lua]);
        } else if (want && floating) {
            // (the rule's wording changed in 0.53: both are sent, the one it doesn't know is refused)
            Quickshell.execDetached(["sh", "-c", "hyprctl keyword windowrule 'match:class .*, float on'; hyprctl keyword windowrulev2 'float, class:.*'"]);
        } else if (!want) {
            // (rules added at runtime only go with a reload; Monolith's own are sent again after it)
            Quickshell.execDetached(["sh", "-c", "hyprctl reload"]);
        }
    }
    // ── windows like KDE Plasma's (scripts/desk-windows.lua, Hyprland): snapping, a window
    // dragged to an edge tiled to that half (a corner: a quarter, the top: maximised) with an
    // outline of where it goes (status/TilePreview.qml), a tiled one dragged away its size again,
    // and a right click on a title bar its menu (status/WindowMenu.qml) ──
    readonly property string kdeScript: Qt.resolvedUrl("../scripts/desk-windows.lua").toString().replace("file://", "")
    readonly property string shellQml: Qt.resolvedUrl("../shell.qml").toString().replace("file://", "")
    function kdeLua() {
        // (the apps without our title bar, by exact name: theirs is under the top of the window)
        const nb = noBar.filter(x => /^[A-Za-z0-9_.+-]+$/.test(x)).map(x => JSON.stringify(String(x).toLowerCase())).join(", ");
        return "; MonolithDesk.kdeCfg = { ipc = " + JSON.stringify(shellQml) + ", bars = " + (titlebars && barsReady ? "true" : "false")
            + ", noBar = { " + nb + " } }; dofile(" + JSON.stringify(kdeScript) + ")";
    }
    // the outline, in screen coordinates (the whole desktop's): { on, x, y, w, h }
    property var preview: ({ on: false, x: 0, y: 0, w: 0, h: 0 })
    // the window menu: { addr, x, y, max, pin, title } while it's open, else null
    property var winMenu: null
    onOnChanged: if (!on) { preview = { on: false, x: preview.x, y: preview.y, w: preview.w, h: preview.h }; winMenu = null; }
    function winAct(kind, a, arg) {
        const s = "address:" + a;
        const lua = {
            min: "MonolithDesk.minimizeWin('" + s + "')",
            max: "hl.dispatch(hl.dsp.window.fullscreen({ mode = 'maximized', action = 'toggle', window = '" + s + "' }))",
            full: "hl.dispatch(hl.dsp.window.fullscreen({ mode = 'fullscreen', action = 'toggle', window = '" + s + "' }))",
            left: "MonolithDesk.tileWin('" + s + "', 'left')",
            right: "MonolithDesk.tileWin('" + s + "', 'right')",
            pin: "hl.dispatch(hl.dsp.window.pin({ action = 'toggle', window = '" + s + "' }))",
            ws: "hl.dispatch(hl.dsp.window.move({ workspace = " + Number(arg) + ", follow = false, window = '" + s + "' }))",
            close: "hl.dispatch(hl.dsp.window.close({ window = '" + s + "' }))"
        }[kind];
        if (lua && /^0x[0-9a-fA-F]+$/.test(a)) Quickshell.execDetached(["hyprctl", "eval", lua]);
    }
    IpcHandler {
        target: "desk"
        function preview(x: int, y: int, w: int, h: int): void { if (desk.on) desk.preview = { on: true, x: x, y: y, w: w, h: h }; }
        function maximize(): void { desk.toggleMax(); }
        function previewOff(): void { const p = desk.preview; desk.preview = { on: false, x: p.x, y: p.y, w: p.w, h: p.h }; }
        function windowMenu(addr: string, x: int, y: int, max: bool, pin: bool, title: string): void {
            if (desk.on) desk.winMenu = { addr: addr, x: x, y: y, max: max, pin: pin, title: title };
        }
    }

    // Meta+T on niri (monolith desk maximize): maximised like on Hyprland, border and gaps kept.
    // niri draws neither on a window it maximises "to edges", and maximising a column takes the
    // window out of floating: in Desktop mode it goes into the tiling layout with its column
    // maximised, and the next press floats it again where it was (it stayed tiled, the column
    // unmaximised: stuck in the tiling layout). Without Desktop mode, as before
    property var maxFloated: ({})
    function toggleMax() {
        if (Niri.hyprland) {
            Hyprland.dispatch(Niri.hyprLua ? 'hl.dsp.window.fullscreen({ mode = "maximized", action = "toggle" })' : "fullscreen 1");
            return;
        }
        const w = Niri.windows[Niri.focusedWindowId];
        if (!w) return;
        const id = String(w.id);
        let acts;
        if (w.is_floating) {
            acts = ["toggle-window-floating --id " + id, "maximize-column"];
            if (on) { const n = Object.assign({}, maxFloated); n[id] = true; maxFloated = n; }
        } else if (on && maxFloated[id]) {
            const n = Object.assign({}, maxFloated); delete n[id]; maxFloated = n;
            acts = ["maximize-column", "toggle-window-floating --id " + id];
        } else if (on) {
            acts = ["toggle-window-floating --id " + id];
        } else {
            acts = ["maximize-column"];
        }
        // (in order, one niri at a time: the column is the focused window's)
        Quickshell.execDetached(["sh", "-c", ["focus-window --id " + id].concat(acts).map(a => "niri msg action " + a).join("; ")]);
    }

    // niri (with patches/niri-drag-edges.patch, a niri extra): the same, niri telling the edge
    // zone under the pointer as a floating window is dragged (core/Niri.qml dragEdge)
    property var niriTiled: ({})      // window id -> [w, h]: its size before it was tiled
    property var niriDrag: null       // { id, output, zone, area, shown } while one is dragged
    Timer { id: zoneDwell; interval: 75; onTriggered: desk.showNiriZone() }
    // a zone's box in an output's working area ([x, y, w, h] of it): [x, y, w, h] within the area
    function zoneRect(z, area) {
        const G = 6, x = G, y = G, w = area[2] - 2 * G, h = area[3] - 2 * G;
        const hw = Math.floor((w - G) / 2), hh = Math.floor((h - G) / 2);
        return ({ "top": [x, y, w, h], "left": [x, y, hw, h], "right": [x + w - hw, y, hw, h],
                  "top-left": [x, y, hw, hh], "top-right": [x + w - hw, y, hw, hh],
                  "bottom-left": [x, y + h - hh, hw, hh], "bottom-right": [x + w - hw, y + h - hh, hw, hh] })[z] || null;
    }
    function screenNamed(name) { for (const sc of Quickshell.screens) if (sc.name === name) return sc; return null; }
    function showNiriZone() {
        const d = niriDrag;
        if (!d || d.zone === "") return;
        const r = zoneRect(d.zone, d.area), sc = screenNamed(d.output);
        if (!r || !sc) return;
        d.shown = true;
        preview = { on: true, x: sc.x + d.area[0] + r[0], y: sc.y + d.area[1] + r[1], w: r[2], h: r[3] };
    }
    function hidePreview() { const p = preview; if (p.on) preview = { on: false, x: p.x, y: p.y, w: p.w, h: p.h }; }
    Connections {
        target: Niri
        function onDragEdge(id, output, zone, area, ended) {
            if (!desk.on || Niri.hyprland) return;
            if (!desk.niriDrag || desk.niriDrag.id !== id) {
                desk.niriDrag = { id: id, output: output, zone: "", area: area, shown: false };
                // a tiled window taken away: the size it had (niri keeps it under the pointer)
                const t = desk.niriTiled[id];
                if (t && !ended) {
                    const n = Object.assign({}, desk.niriTiled); delete n[id]; desk.niriTiled = n;
                    desk.niriSize(id, t[0], t[1]);
                }
            }
            const d = desk.niriDrag;
            if (ended) {
                // (put there only when its outline was showing, as KDE does)
                const go = zone !== "" && zone === d.zone && d.shown;
                desk.niriDrag = null;
                zoneDwell.stop();
                desk.hidePreview();
                if (go) desk.niriTile(id, zone, area);
                return;
            }
            if (zone !== d.zone || output !== d.output) {
                d.zone = zone; d.output = output; d.area = area; d.shown = false;
                desk.hidePreview();
                zoneDwell.stop();
                if (zone !== "") zoneDwell.restart();
            }
        }
    }
    function niriSize(id, w, h, x, y) {
        // (one after the other: each its own process, they could come in any order)
        let cmd = "niri msg action set-window-width --id \"$1\" \"$2\"; niri msg action set-window-height --id \"$1\" \"$3\"";
        if (x !== undefined) cmd += "; niri msg action move-floating-window --id \"$1\" -x \"$4\" -y \"$5\"";
        Quickshell.execDetached(["sh", "-c", cmd, "_", String(id), String(Math.round(w)), String(Math.round(h)), String(Math.round(x || 0)), String(Math.round(y || 0))]);
    }
    function niriTile(id, zone, area) {
        const w = Niri.windows[id];
        if (zone === "top") { if (w) maximize(w); return; }
        const r = zoneRect(zone, area);
        if (!r) return;
        if (w && w.layout && w.layout.window_size && !niriTiled[id]) {
            const n = Object.assign({}, niriTiled); n[id] = [w.layout.window_size[0], w.layout.window_size[1]]; niriTiled = n;
        }
        // (move-floating-window counts from the working area's corner, as the zone does)
        niriSize(id, r[2], r[3], r[0], r[1]);
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
    Connections { target: Niri; function onWindowsChanged() { if (desk.on && desk.floating) sizeLater.restart(); desk.niriOpened(); } }
    // niri: a window opening, the first of its app, gets the size its app had (a rule per app
    // made its other windows, a screen-share picker or a dialog, as big as its main one too)
    property var seenIds: null
    // niri: a window that opened fullscreen (mpv --fs, a video player's next file) never had a
    // floating place: out of fullscreen niri floats it at its own small size in the screen's top
    // left corner. It gets its app's size and the middle of the screen, like a window opening
    property var wasFloating: ({})
    Connections {
        target: Niri
        function onWindowsChanged() {
            if (Niri.hyprland) return;
            const now = {};
            for (const k in Niri.windows) {
                const w = Niri.windows[k];
                now[k] = w.is_floating;
                if (!desk.on || !desk.floating || !w.is_floating || desk.wasFloating[k] !== false || desk.isMin(w)) continue;
                const pos = w.layout ? w.layout.tile_pos_in_workspace_view : null;
                if (!pos || pos[0] > 1 || pos[1] > 1) continue;
                const s = desk.sizes[String(w.app_id || "").toLowerCase()];
                if (s) {
                    desk.niri(["set-window-width", "--id", String(w.id), String(Math.round(s[0]))]);
                    desk.niri(["set-window-height", "--id", String(w.id), String(Math.round(s[1]))]);
                }
                desk.centerLater(w.id);
            }
            desk.wasFloating = now;
        }
    }
    // niri keeps a floating window's place from the top of the room it gives: the bar (and the mini
    // bars that go with it) starting or stopping to keep room (auto-hide on or off, Meta+A) moved
    // every window up or down. Where they were is noted the moment that changes, and they're put back
    property var keepAt: null
    function noteKeep() {
        if (Niri.hyprland || !on) return;
        const m = {};
        for (const k in Niri.windows) {
            const w = Niri.windows[k];
            if (!w || !w.is_floating || isMin(w)) continue;
            const p = w.layout ? w.layout.tile_pos_in_workspace_view : null;
            if (p) m[k] = [p[0], p[1]];
        }
        keepAt = m;
        keepTries = 0;
        keepFor.restart();
    }
    function putBack() {
        for (const k in keepAt) {
            const w = Niri.windows[k], t = keepAt[k];
            const p = w && w.layout ? w.layout.tile_pos_in_workspace_view : null;
            if (!p || (Math.abs(p[0] - t[0]) <= 1 && Math.abs(p[1] - t[1]) <= 1)) continue;
            // (by the difference: niri's absolute place counts from the top of the room it gives,
            // which is just what moved)
            const dx = Math.round(t[0] - p[0]), dy = Math.round(t[1] - p[1]);
            niri(["move-floating-window", "--id", String(k), "-x", (dx >= 0 ? "+" : "") + dx, "-y", (dy >= 0 ? "+" : "") + dy]);
        }
    }
    // (looked at a few times as niri takes the new room: it doesn't always say a floating window
    // moved for that)
    property int keepTries: 0
    Timer { id: keepFor; interval: 150; repeat: true; onTriggered: { desk.putBack(); if (++desk.keepTries >= 8) { stop(); desk.keepAt = null; } } }
    Connections { target: Theme; function onBarTucksChanged() { desk.noteKeep(); } }
    // (centred once its new size has been taken: centred straight after the resize, niri used the
    // old size and the window sat at the top)
    property var toCenter: []
    function centerLater(id) { toCenter = toCenter.concat([id]); centerTimer.restart(); }
    Timer { id: centerTimer; interval: 250; onTriggered: { for (const id of desk.toCenter) desk.niri(["center-window", "--id", String(id)]); desk.toCenter = []; } }
    function niriOpened() {
        if (Niri.hyprland) return;
        const now = {}, fresh = [];
        for (const k in Niri.windows) { now[k] = true; if (seenIds && !seenIds[k]) fresh.push(k); }
        seenIds = now;
        if (!on || !floating) return;
        for (const k of fresh) {
            const w = Niri.windows[k];
            const id = String(w.app_id || "").toLowerCase();
            const s = sizes[id];
            if (!s || !w.is_floating) continue;
            // (not one an open window of the same process opened: a dialog, a picker)
            let n = 0;
            for (const j in Niri.windows) { const o = Niri.windows[j]; if (j !== k && String(o.app_id || "").toLowerCase() === id && o.pid === w.pid) n++; }
            if (n > 0) continue;
            niri(["set-window-width", "--id", String(w.id), String(Math.round(s[0]))]);
            niri(["set-window-height", "--id", String(w.id), String(Math.round(s[1]))]);
            centerLater(w.id);
        }
    }
    function noteSizes() {
        const cur = Object.assign({}, sizes);
        const biggest = {};
        let changed = false;
        // (the window you're in: resizing a window puts you in it. Not one that's only a little
        // window, a splash screen or a dialog: Vesktop's splash came out as its size)
        const ids = Object.keys(Niri.windows).filter(k => Niri.windows[k].is_focused);
        for (const k of ids) {
            const w = Niri.windows[k];
            if (!w || !w.is_floating || w.is_fullscreen || isMin(w)) continue;
            const sz = w.layout ? w.layout.window_size : null;
            const id = String(w.app_id || "").toLowerCase();
            if (!sz || id === "" || sz[0] < 480 || sz[1] < 360) continue;
            const ws = Niri.workspaces.find(x => x.id === w.workspace_id);
            const scr = ws ? Quickshell.screens.find(x => x.name === ws.output) : null;
            if (scr && (sz[0] >= scr.width * 0.95 || sz[1] >= scr.height * 0.88)) continue;
            const v = [Math.round(sz[0]), Math.round(sz[1])];
            // (an app with several windows: its biggest, its main one, not a dialog of it)
            const big = biggest[id];
            if (big && big[0] * big[1] > v[0] * v[1]) continue;
            biggest[id] = v;
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
                if (desk.titlebars && desk.barsReady) desk.hyprBars(true);
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
