pragma Singleton
import QtQuick
import Quickshell

// Widget layouts: the desktop's (per screen) and the lock screen's. Each item is
// { id, type, face, x, y, scale, screen } with x/y as fractions of the screen (its top-left).
// The widget editor (wall/WidgetEditor.qml) changes them; Widgets.qml and the lock screen draw them.
Singleton {
    id: wl
    // every widget there is: [type, name, icon]; and each type's looks: [face, name]
    readonly property var types: [
        ["clock", "Clock", "schedule"], ["date", "Date", "today"], ["weather", "Weather", "partly_cloudy_day"],
        ["media", "Now playing", "music_note"], ["calendar", "Calendar", "calendar_month"], ["usage", "System usage", "memory"],
        ["notes", "Notes", "sticky_note_2"], ["image", "Picture", "image"], ["greeting", "Greeting", "waving_hand"],
        ["notifications", "Notifications", "notifications"]
    ]
    readonly property var faces: ({
        clock: [["digital", "Digital"], ["stacked", "Stacked"], ["analog", "Analog"], ["minimal", "Minimal"]],
        date: [["full", "Full"], ["compact", "Compact"]],
        weather: [["pill", "Pill"], ["full", "With hours"]],
        media: [["card", "Card"], ["cover", "Cover"]],
        calendar: [["month", "Month"]],
        usage: [["rings", "Rings"], ["bars", "Bars"]],
        notes: [["card", "Card"]],
        image: [["rounded", "Rounded"], ["circle", "Circle"]],
        greeting: [["text", "Text"]],
        notifications: [["list", "List"]]
    })
    function typeName(t) { const x = types.find(y => y[0] === t); return x ? x[1] : t; }
    function typeIcon(t) { const x = types.find(y => y[0] === t); return x ? x[2] : "widgets"; }
    function faceName(t, f) { const x = (faces[t] || []).find(y => y[0] === f); return x ? x[1] : ((faces[t] || [["", "Default"]])[0][1]); }

    // what's there to start with: the desktop keeps the earlier widgets you had on; the lock
    // screen gets a clock, the date, notifications and now playing
    readonly property var desktopDefault: {
        const old = [["clock", 0.05, 0.62], ["weather", 0.05, 0.84], ["media", 0.72, 0.84], ["calendar", 0.80, 0.08], ["usage", 0.05, 0.08], ["notes", 0.80, 0.42], ["image", 0.42, 0.08]];
        const on = { clock: true, weather: true, media: true };
        return old.filter(o => Store.get("widgets.hidden." + o[0], !on[o[0]]) !== true)
                  .map((o, i) => ({ id: "d" + i, type: o[0], face: "", x: o[1], y: o[2], scale: 1, screen: "" }));
    }
    readonly property var lockDefault: [
        { id: "l0", type: "clock", face: "stacked", x: 0.42, y: 0.12, scale: 1, screen: "" },
        { id: "l1", type: "date", face: "compact", x: 0.44, y: 0.45, scale: 1, screen: "" },
        { id: "l2", type: "notifications", face: "list", x: 0.03, y: 0.72, scale: 1, screen: "" },
        { id: "l3", type: "media", face: "card", x: 0.72, y: 0.82, scale: 1, screen: "" }
    ]
    function key(mode) { return mode === "lock" ? "lock.items" : "widgets.items"; }
    function items(mode) { return Store.get(key(mode), null) || (mode === "lock" ? lockDefault : desktopDefault); }
    // the ones on a screen (an item without a screen shows on the first one)
    function on(mode, screen) {
        const first = Quickshell.screens.length ? Quickshell.screens[0].name : "";
        return items(mode).filter(i => (i.screen || first) === screen || mode === "lock");
    }
    function save(mode, list) { Store.set(key(mode), list); }
    function update(mode, id, changes) { save(mode, items(mode).map(i => i.id === id ? Object.assign({}, i, changes) : i)); }
    function remove(mode, id) { save(mode, items(mode).filter(i => i.id !== id)); }
    function add(mode, type, screen) {
        const id = type[0] + Date.now().toString(36);
        save(mode, items(mode).concat([{ id: id, type: type, face: "", x: 0.4, y: 0.4, scale: 1, screen: mode === "lock" ? "" : screen }]));
        return id;
    }
    function nextFace(mode, item, d) {
        const fs = faces[item.type] || [];
        if (fs.length < 2) return;
        const i = Math.max(0, fs.findIndex(f => f[0] === item.face));
        update(mode, item.id, { face: fs[(i + d + fs.length) % fs.length][0] });
    }
    function reset(mode) { Store.set(key(mode), null); }
}
