pragma Singleton
import QtQuick
import Quickshell
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
