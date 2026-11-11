pragma Singleton
import QtQuick
import Quickshell

// Notes: a list of notes ({ id, title, content, pinned, updatedAt }) shared by the notes widget,
// Tools and quick access, kept in the store as notes.list. The single note of earlier versions
// (notes.text) becomes the first one.
Singleton {
    id: n
    readonly property var list: {
        const l = Store.get("notes.list", null);
        if (Array.isArray(l)) return l;
        const old = Store.get("notes.text", "");
        return old ? [{ id: "n1", title: "", content: old, pinned: false, updatedAt: Date.now() }] : [];
    }
    // pinned first, then the most recently changed (pinned always true or false: notes saved
    // without it made a second "Recent" group)
    readonly property var sorted: list.map(o => o.pinned === true || o.pinned === false ? o : Object.assign({}, o, { pinned: false }))
                                      .sort((a, b) => (b.pinned === true) - (a.pinned === true) || (b.updatedAt || 0) - (a.updatedAt || 0))
    // deleted notes, newest first (the last 30), to bring back
    readonly property var trash: Store.get("notes.trash", []) || []

    function find(id) { return list.find(x => x.id === id) || null; }
    function save(l) { Store.set("notes.list", l); }
    function create() {
        const id = "n" + Date.now().toString(36);
        save([{ id: id, title: "", content: "", pinned: false, updatedAt: Date.now() }].concat(list));
        return id;
    }
    function edit(id, title, content) {
        const x = find(id);
        if (!x || (x.title === title && x.content === content)) return;
        save(list.map(o => o.id === id ? Object.assign({}, o, { title: title, content: content, updatedAt: Date.now() }) : o));
    }
    function togglePin(id) { save(list.map(o => o.id === id ? Object.assign({}, o, { pinned: !o.pinned }) : o)); }
    function remove(id) {
        const x = find(id);
        // (an empty note isn't worth keeping)
        if (x && ((x.title || "").trim() !== "" || (x.content || "").trim() !== ""))
            Store.set("notes.trash", [Object.assign({}, x, { deletedAt: Date.now() })].concat(trash).slice(0, 30));
        save(list.filter(o => o.id !== id));
    }
    function restore(id) {
        const x = trash.find(o => o.id === id);
        if (!x) return;
        const back = Object.assign({}, x, { updatedAt: Date.now() });
        delete back.deletedAt;
        save([back].concat(list.filter(o => o.id !== id)));
        Store.set("notes.trash", trash.filter(o => o.id !== id));
    }
    function emptyTrash() { Store.set("notes.trash", []); }
    // a note as plain text (its title on top), for the clipboard
    function text(o) { return !o ? "" : ((o.title || "").trim() !== "" ? o.title.trim() + "\n\n" : "") + (o.content || ""); }
    function copy(o) { const t = text(o); if (t !== "") Quickshell.execDetached(["wl-copy", "--", t]); }
    // a note's name: its title, else its first line
    function name(o) {
        if (!o) return "";
        if (o.title && o.title.trim() !== "") return o.title.trim();
        const first = (o.content || "").split("\n").find(l => l.trim() !== "");
        return first ? first.trim() : "New note";
    }
    function when(t) {
        const d = (Date.now() - (t || 0)) / 1000;
        if (d < 60) return "just now";
        if (d < 3600) return Math.floor(d / 60) + " min ago";
        const a = new Date(t), now = new Date();
        if (a.toDateString() === now.toDateString()) return Qt.formatTime(a, "HH:mm");
        if (d < 7 * 86400) return Qt.formatDate(a, "ddd");
        return Qt.formatDate(a, "d MMM");
    }
}
