pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Hyprland

// Alt+Tab on Hyprland (niri has its own switcher: core/AltTab). Hyprland has none, so its keys
// (install/modules/hypr_keys.py) hand Alt+Tab to the shell as global shortcuts:
//   quickshell:monolith-alttab        Alt+Tab        the next window (most recent first)
//   quickshell:monolith-alttab-back   Alt+Shift+Tab  the one before
//   quickshell:monolith-alttab-done   letting go of Alt (a release bind that passes the key on)
// A quick Alt+Tab just goes back to the last window; held a moment, the switcher shows every
// window on every workspace with a live preview (status/WindowSwitcher), and letting go of Alt
// switches. The order is kept here from focus changes, so it's the order you used them in.
Singleton {
    id: sw
    readonly property bool on: Niri.hyprland
    // window ids, the most recently focused first
    property var mru: []
    // Alt is held and Tab was pressed: cycling
    property bool active: false
    // the switcher is showing
    property bool open: false
    property int index: 0
    // the windows when cycling started (they don't reorder under your fingers)
    property var list: []

    readonly property bool picture: Store.get("alttab.hyprShow", true) !== false
    readonly property int delay: Number(Store.get("alttab.hyprDelay", 150))

    Connections {
        target: sw.on ? Niri : null
        function onFocusedWindowIdChanged() { sw.touch(Niri.focusedWindowId); }
        function onWindowsChanged() { sw.prune(); }
    }
    function touch(id) {
        if (id === null || id === undefined || sw.active) return;
        const m = mru.filter(x => x !== id);
        m.unshift(id);
        mru = m;
    }
    // closed windows out, new ones in. With no order of its own yet (the shell just started or
    // reloaded) it takes Hyprland's; a window it hasn't seen goes where Hyprland's order puts it.
    // (The order used to be whatever the window list happened to be: when the window you were on
    // wasn't first, Alt+Tab "switched" to it, so nothing happened, and as focus never changed the
    // order never got fixed either)
    function prune() {
        const ws = Niri.windows;
        const hist = id => ws[id] && typeof ws[id].focus_history === "number" ? ws[id].focus_history : 1000000;
        const ids = Object.keys(ws).sort((a, b) => hist(a) - hist(b));
        const m = mru.filter(x => ids.indexOf(x) !== -1);
        for (const k of ids) {
            if (m.indexOf(k) !== -1) continue;
            const at = m.findIndex(x => hist(x) > hist(k));
            if (at === -1) m.push(k); else m.splice(at, 0, k);
        }
        mru = m;
    }

    function step(d) {
        if (!on) return;
        if (!active) {
            prune();
            // the window you're on comes first, whatever happened while the order wasn't watched
            const f = Niri.focusedWindowId;
            const l = mru.map(id => Niri.windows[id]).filter(w => !!w && w.workspace_id !== null);
            const fi = l.findIndex(w => w.id === f);
            if (fi > 0) l.unshift(l.splice(fi, 1)[0]);
            if (l.length === 0) return;
            list = l;
            // (nothing focused, say an empty workspace: the first one is the last window you used)
            index = fi === -1 ? (d > 0 ? -1 : 0) : 0;
            active = true;
            if (picture) show.restart();
        }
        index = (index + d + list.length) % list.length;
    }
    function done() {
        if (!active) return;
        const w = list[index];
        active = false;
        open = false;
        show.stop();
        list = [];
        if (w && w.id !== Niri.focusedWindowId) Niri.action(["focus-window", "--id", String(w.id)]);
    }
    function pick(i) { if (active && i >= 0 && i < list.length) { index = i; done(); } }
    function cancel() { active = false; open = false; show.stop(); list = []; }

    Timer { id: show; interval: Math.max(0, sw.delay); onTriggered: if (sw.active) sw.open = true }
    // (a lost release, say Alt let go while a game had grabbed the keyboard: don't stay open)
    Timer { interval: 15000; running: sw.active; onTriggered: sw.cancel() }

    GlobalShortcut { appid: "quickshell"; name: "monolith-alttab"; description: "Alt+Tab: next window"; onPressed: sw.step(1) }
    GlobalShortcut { appid: "quickshell"; name: "monolith-alttab-back"; description: "Alt+Shift+Tab: previous window"; onPressed: sw.step(-1) }
    // (a release bind: whichever of the two Hyprland sends, it means Alt was let go)
    GlobalShortcut { appid: "quickshell"; name: "monolith-alttab-done"; description: "Alt let go: switch"; onPressed: sw.done(); onReleased: sw.done() }
}
