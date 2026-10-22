pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import "../../"

// Todo list for the dashboard, kept in ~/.local/state/monolith/todo.json.
Item {
    id: root

    property var items: []
    readonly property int openCount: items.filter(i => !i.done).length

    function add(text) {
        let t = String(text || "").trim();
        if (t === "") return;
        root.items = root.items.concat([{ "id": Date.now(), "text": t, "done": false }]);
        save();
    }
    function toggle(id) {
        root.items = root.items.map(i => i.id === id ? Object.assign({}, i, { "done": !i.done }) : i);
        save();
    }
    function remove(id) {
        root.items = root.items.filter(i => i.id !== id);
        save();
    }
    function clearDone() {
        root.items = root.items.filter(i => !i.done);
        save();
    }

    function save() {
        file.setText(JSON.stringify(root.items, null, 2));
    }

    FileView {
        id: file
        path: Caching.stateDir + "/todo.json"
        watchChanges: true
        onFileChanged: reload()
        onLoaded: {
            try {
                let d = JSON.parse(text());
                if (Array.isArray(d)) root.items = d;
            } catch (e) {}
        }
        onLoadFailed: root.items = []
    }
}
