pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Notifications

// The notification server: every notification is kept (the history page) and new ones are
// also shown as popups until they time out, unless Do Not Disturb is on.
Singleton {
    id: notifs
    property bool dnd: Store.get("notifications.dnd", false)
    onDndChanged: if (Store.loaded && Store.get("notifications.dnd", false) !== dnd) Store.set("notifications.dnd", dnd)
    // newest first
    readonly property var list: server.trackedNotifications.values.slice().reverse()
    property var popups: []
    property var _until: ({})          // notification id -> when its popup leaves (ms)
    // the pointer is on the popups: nobody leaves. One entry per place showing them (each screen's
    // island, each screen's corner stack), each only while it shows some: a single flag set by
    // "hovered" alone stuck on when the card under the pointer went away without a "left", and
    // then nothing ever timed out again (they piled up under the notification list)
    property var holders: ({})
    readonly property bool hold: Object.keys(holders).length > 0
    function setHold(who, on) {
        if (!!holders[who] === on) return;
        const h = Object.assign({}, holders);
        if (on) h[who] = true; else delete h[who];
        holders = h;
    }
    // opening the notification list (the bell's dropdown, the Notifications page): the popups
    // have been seen, they go (they stay in the list); they used to stay up under it
    Connections {
        target: HubState
        function onDropKindChanged() { notifs._listOpened(); }
        function onOpenChanged() { notifs._listOpened(); }
        function onPageChanged() { notifs._listOpened(); }
    }
    function _listOpened() {
        const open = (HubState.dropKind === "notifications" && HubState.dropScreen !== "") || (HubState.open && HubState.page === "notifications");
        if (open && popups.length) { _leave(popups.filter(p => !leaving[p.id])); holders = ({}); }
    }

    // another notification program holding the bus name (mako, dunst, swaync… usually started
    // by D-Bus on its own while the shell was restarting): it then shows its own popups and
    // Monolith gets nothing. "" when it's ours. Settings → Notifications offers to hand it back.
    property string otherDaemon: ""
    function checkOwner() { if (!ownerProc.running) ownerProc.running = true; }
    Process {
        id: ownerProc
        command: ["sh", "-c", "busctl --user status org.freedesktop.Notifications 2>/dev/null | sed -n 's/^Comm=//p'"]
        stdout: StdioCollector { onStreamFinished: { const c = text.trim(); notifs.otherDaemon = c !== "" && c !== "quickshell" && c !== "qs" ? c : ""; } }
    }
    Timer { interval: 4000; running: true; onTriggered: notifs.checkOwner() }
    // (often while another one has it, so the warning goes as soon as it's ours again)
    Timer { interval: notifs.otherDaemon !== "" ? 3000 : 60000; running: true; repeat: true; onTriggered: notifs.checkOwner() }
    // stop it, keep D-Bus from starting it again (a user service file for its name that runs
    // nothing; delete it to undo), and let Monolith take the name back
    function takeBack() {
        const who = otherDaemon;
        if (!who) return;
        Quickshell.execDetached(["sh", "-c",
            "d=\"${XDG_DATA_HOME:-$HOME/.local/share}/dbus-1/services\"; mkdir -p \"$d\"; " +
            "for f in /usr/share/dbus-1/services/*.service /usr/local/share/dbus-1/services/*.service; do " +
            "  [ -f \"$f\" ] || continue; grep -q '^Name=org.freedesktop.Notifications' \"$f\" || continue; " +
            "  b=$(basename \"$f\"); [ -e \"$d/$b\" ] || printf '[D-BUS Service]\\nName=org.freedesktop.Notifications\\nExec=/bin/false\\n# Monolith shows notifications; delete this file to let %s start again\\n' \"$b\" > \"$d/$b\"; done; " +
            "pkill -x \"$1\"; sleep 1; true", "_", who]);
        restartCheck.start();
    }
    Timer { id: restartCheck; interval: 2500; onTriggered: notifs.checkOwner() }
    // the screen each popup came up on: it stays there (switching windows to another screen
    // doesn't move it)
    property var _screen: ({})         // notification id -> output name
    function screenOf(n) { return n ? (_screen[n.id] || "") : ""; }
    function popupsOn(output, first) { return popups.filter(p => (screenOf(p) || first) === output); }
    // popups on their way out: they stay in the list a moment so they can slide away
    property var leaving: ({})         // notification id -> true
    readonly property int leaveMs: 240
    function _leave(list) {
        if (!list.length) return;
        const l = Object.assign({}, leaving);
        for (const n of list) l[n.id] = true;
        leaving = l;
        const ids = list.map(n => n.id);
        Qt.callLater(() => gone.schedule(ids));
    }
    QtObject {
        id: gone
        property var queue: []
        function schedule(ids) { queue = queue.concat([{ ids: ids, at: Date.now() + notifs.leaveMs }]); goneTimer.restart(); }
    }
    Timer {
        id: goneTimer
        interval: 60; repeat: true
        onTriggered: {
            const now = Date.now();
            const due = gone.queue.filter(q => q.at <= now);
            if (!due.length) return;
            gone.queue = gone.queue.filter(q => q.at > now);
            const ids = [].concat(...due.map(q => q.ids));
            notifs.popups = notifs.popups.filter(p => ids.indexOf(p.id) === -1);
            const l = Object.assign({}, notifs.leaving);
            for (const id of ids) delete l[id];
            notifs.leaving = l;
            if (!gone.queue.length) stop();
        }
    }

    // gone at once (swiped away: it already flew off), or sliding away (clicked, timed out)
    function dismissPopup(n, now) {
        if (now) { popups = popups.filter(p => p !== n); return; }
        if (popups.indexOf(n) !== -1 && !leaving[n.id]) _leave([n]);
    }
    function _expire() {
        const now = Date.now();
        if (hold) {
            const u = {};
            for (const p of popups) u[p.id] = Math.max(_until[p.id] || 0, now + 2000);
            _until = u;
            return;
        }
        _leave(popups.filter(p => p.urgency !== NotificationUrgency.Critical && (_until[p.id] || 0) <= now && !leaving[p.id]));
    }
    Timer { interval: 400; repeat: true; running: notifs.popups.length > 0; onTriggered: notifs._expire() }
    // the sound: your own file (Settings → Notifications), or the system's
    // system | pack | file (a file picked before there was a choice: file)
    function soundStyle() { return Store.get("notifications.soundStyle", Store.get("notifications.soundFile", "") !== "" ? "file" : "system"); }
    function playSound(urgent) {
        // the sound pack's own chime (Settings → Sound → Sounds), else your file or the system's
        const style = soundStyle();
        if (style === "pack") { Sounds.playAlways(urgent ? "error" : "notify"); return; }
        const own = style === "file" ? Store.get("notifications.soundFile", "") : "";
        Quickshell.execDetached(["pw-play", own !== "" && !urgent ? own : (urgent
            ? "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
            : "/usr/share/sounds/freedesktop/stereo/message.oga")]);
    }
    function showPopup(n, where) {
        const u = Object.assign({}, _until);
        u[n.id] = Date.now() + (n.expireTimeout > 0 ? n.expireTimeout * 1000 : Number(Store.get("notifications.timeout", 6)) * 1000);
        _until = u;
        const sc = Object.assign({}, _screen);
        sc[n.id] = where;
        _screen = sc;
        // more than four: the oldest slides away
        _leave(popups.filter(p => !leaving[p.id]).slice(3));
        popups = [n].concat(popups);
    }
    // held back while a fullscreen app covered their screen: [{ n, app, out }]; once it isn't
    // fullscreen any more, one comes up as it is, more as a summary
    property var held: []
    function holdBack(n, out) { held = held.concat([{ n: n, app: n.appName || "An app", out: out }]); }
    Timer {
        interval: 1000; repeat: true
        running: notifs.held.length > 0
        onTriggered: {
            const outs = [...new Set(notifs.held.map(h => h.out))].filter(o => !Niri.fullscreenOn(o));
            if (!outs.length) return;
            const back = notifs.held.filter(h => outs.indexOf(h.out) !== -1);
            notifs.held = notifs.held.filter(h => outs.indexOf(h.out) === -1);
            const alive = back.filter(h => notifs.list.indexOf(h.n) !== -1);
            if (alive.length === 1) { notifs.showPopup(alive[0].n, alive[0].out); return; }
            if (!alive.length) return;
            const per = {};
            for (const h of alive) per[h.app] = (per[h.app] || 0) + 1;
            const body = Object.keys(per).map(k => per[k] > 1 ? k + " (" + per[k] + ")" : k).join(", ");
            Quickshell.execDetached(["notify-send", "-a", "Monolith",
                "-h", "boolean:suppress-sound:true",
                alive.length + " notifications while you were in fullscreen", body + ". They're in the notification list."]);
        }
    }
    // Clear: with animations on, the cards on screen are thrown all over first (core/Throw;
    // copies fly, so the real ones can go a moment later, once the copies are up)
    function clearAll() {
        Throw.scattered = 0;
        if (Throw.on) Throw.scatter();
        if (Throw.scattered > 0) clearLater.restart(); else clearNow();
    }
    function clearNow() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        popups = [];
    }
    Timer { id: clearLater; interval: 260; onTriggered: notifs.clearNow() }
    // `qs ipc call notifications clear`: the same as the Clear button (thrown away too)
    IpcHandler {
        target: "notifications"
        function clear(): void { notifs.clearAll(); }
    }

    NotificationServer {
        id: server
        keepOnReload: true
        actionsSupported: true
        bodySupported: true
        bodyMarkupSupported: true
        imageSupported: true
        persistenceSupported: true
        onNotification: n => {
            n.tracked = true;
            if (!notifs.dnd || n.urgency === NotificationUrgency.Critical) {
                const out = Niri.focusedOutput !== "" ? Niri.focusedOutput : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
                // a fullscreen app (a game) on that screen: the popup goes to another screen, or
                // waits until it's no longer fullscreen (Settings → Notifications → While fullscreen)
                const mode = Store.get("notifications.fullscreen", "other");
                const covered = n.urgency !== NotificationUrgency.Critical && mode !== "show" && Niri.fullscreenOn(out);
                let where = out;
                if (covered) {
                    const free = Quickshell.screens.map(s => s.name).filter(x => x !== out && !Niri.fullscreenOn(x));
                    if (mode === "other" && free.length) where = free[0];
                    else { notifs.holdBack(n, out); where = ""; }
                }
                if (where !== "") notifs.showPopup(n, where);
                if (Store.get("notifications.sound", true) && !n.hints["suppress-sound"] && (!covered || Store.get("notifications.fullscreenSound", false) === true))
                    notifs.playSound(n.urgency === NotificationUrgency.Critical);
            }
            n.closed.connect(() => notifs.dismissPopup(n, true));
        }
    }
}
