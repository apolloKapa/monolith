pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Hyprland

// Desktop mode (Settings → Desktop → Desktop mode; experimental): the shell as a desktop. The bar
// goes to the taskbar's edge (where the dock is, unless you pick another) and spreads across it,
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
            "bar.position": edge,
            "bar.style": "fill",
            "bar.lengthMode": "percent",
            "bar.length": 1,
            "bar.height": size,
            "bar.modules": mods,
            "status.autohide": false,
            "dock.exclusive": false,
            // the start menu comes up out of the taskbar, over its start button
            "menus.barPlaces.search": appsAt === "start" ? "start" : "center"
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
    Connections { target: Niri; function onHyprKnownChanged() { if (desk.on && Niri.hyprland) desk.hyprRules(true); } }
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
        if (Niri.hyprland) return;
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
                +   "hl.dispatch(hl.dsp.window.move({ workspace = \"special:" + minName + "\", follow = false, window = \"address:\" .. a })) end) end";
            Quickshell.execDetached(["hyprctl", "eval", lua]);
        } else if (want && floating) {
            // (the rule's wording changed in 0.53: both are sent, the one it doesn't know is refused)
            Quickshell.execDetached(["sh", "-c", "hyprctl keyword windowrule 'match:class .*, float on'; hyprctl keyword windowrulev2 'float, class:.*'"]);
        } else if (!want) {
            // (rules added at runtime only go with a reload; Monolith's own are sent again after it)
            Quickshell.execDetached(["sh", "-c", "hyprctl reload"]);
        }
    }
    Connections {
        target: Niri.hyprland ? Hyprland : null
        function onRawEvent(ev) {
            if (ev.name !== "configreloaded") return;
            Niri.hyprStill();
            if (desk.on) desk.hyprRules(true);
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
