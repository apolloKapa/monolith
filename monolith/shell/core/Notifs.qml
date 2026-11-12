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
    property bool hold: false          // the pointer is on the popups: nobody leaves

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
    function playSound(urgent) {
        const own = Store.get("notifications.soundFile", "");
        Quickshell.execDetached(["pw-play", own !== "" && !urgent ? own : (urgent
            ? "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
            : "/usr/share/sounds/freedesktop/stereo/message.oga")]);
    }
    function clearAll() {
        for (const n of server.trackedNotifications.values.slice()) n.dismiss();
        popups = [];
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
                const u = Object.assign({}, notifs._until);
                u[n.id] = Date.now() + (n.expireTimeout > 0 ? n.expireTimeout * 1000 : Number(Store.get("notifications.timeout", 6)) * 1000);
                notifs._until = u;
                const sc = Object.assign({}, notifs._screen);
                sc[n.id] = Niri.focusedOutput !== "" ? Niri.focusedOutput : (Quickshell.screens.length ? Quickshell.screens[0].name : "");
                notifs._screen = sc;
                // more than four: the oldest slides away
                notifs._leave(notifs.popups.filter(p => !notifs.leaving[p.id]).slice(3));
                notifs.popups = [n].concat(notifs.popups);
                if (Store.get("notifications.sound", true) && !n.hints["suppress-sound"])
                    notifs.playSound(n.urgency === NotificationUrgency.Critical);
            }
            n.closed.connect(() => notifs.dismissPopup(n, true));
        }
    }
}
