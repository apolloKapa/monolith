import QtQuick
import "../../core"

// The newest notifications as a model that changes one row at a time (for the notification widgets'
// ListViews, so a new one comes in and a gone one goes out, each animated, the rest gliding to make
// room). A Repeater over a slice of Notifs.list rebuilt every row on every change: they all snapped.
// Each row is { nid }; `note(nid)` is its notification.
ListModel {
    id: feed
    property int max: 3
    property var byId: ({})
    function note(nid) { return byId[nid] || null; }
    function idAt(i) { const r = feed.get(i); return r ? r.nid : -1; }
    function sync() {
        const want = Notifs.list.slice(0, Math.max(1, max));
        const m = {};
        for (const n of want) m[n.id] = n;
        // (a row going out keeps its notification until it's gone: it animates with its words)
        const keep = Object.assign({}, byId, m);
        byId = keep;
        // gone ones out (from the end, so the indexes hold)
        for (let i = count - 1; i >= 0; i--) if (!m[idAt(i)]) remove(i);
        // new ones in, in their place
        for (let i = 0; i < want.length; i++) {
            const id = want[i].id;
            if (i < count && idAt(i) === id) continue;
            let at = -1;
            for (let j = i + 1; j < count; j++) if (idAt(j) === id) { at = j; break; }
            if (at >= 0) move(at, i, 1);
            else insert(i, { nid: id });
        }
        while (count > want.length) remove(count - 1);
        // (the ones that went, forgotten a moment later)
        tidy.restart();
    }
    property Timer tidy: Timer {
        interval: 2000
        onTriggered: { const m = {}; for (let i = 0; i < feed.count; i++) { const id = feed.idAt(i); if (feed.byId[id]) m[id] = feed.byId[id]; } feed.byId = m; }
    }
    property Connections watch: Connections { target: Notifs; function onListChanged() { feed.sync(); } }
    Component.onCompleted: sync()
    onMaxChanged: sync()
}
