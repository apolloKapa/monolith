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

    function dismissPopup(n) { popups = popups.filter(p => p !== n); }
    function _expire() {
        const now = Date.now();
        if (hold) {
            const u = {};
            for (const p of popups) u[p.id] = Math.max(_until[p.id] || 0, now + 2000);
            _until = u;
            return;
        }
        popups = popups.filter(p => p.urgency === NotificationUrgency.Critical || (_until[p.id] || 0) > now);
    }
    Timer { interval: 400; repeat: true; running: notifs.popups.length > 0; onTriggered: notifs._expire() }
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
                u[n.id] = Date.now() + (n.expireTimeout > 0 ? n.expireTimeout * 1000 : 6000);
                notifs._until = u;
                notifs.popups = [n].concat(notifs.popups).slice(0, 4);
                if (Store.get("notifications.sound", true) && !n.hints["suppress-sound"])
                    Quickshell.execDetached(["pw-play", n.urgency === NotificationUrgency.Critical
                        ? "/usr/share/sounds/freedesktop/stereo/dialog-warning.oga"
                        : "/usr/share/sounds/freedesktop/stereo/message.oga"]);
            }
            n.closed.connect(() => notifs.dismissPopup(n));
        }
    }
}
