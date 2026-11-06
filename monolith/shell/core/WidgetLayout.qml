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
        ["media", "Now playing", "music_note"], ["visualizer", "Visualiser", "graphic_eq"], ["calendar", "Calendar", "calendar_month"],
        ["usage", "System usage", "memory"], ["cpu", "CPU", "developer_board"], ["ram", "Memory", "memory_alt"],
        ["temp", "Temperature", "device_thermostat"], ["disk", "Disk", "hard_drive"], ["battery", "Battery", "battery_full"],
        ["github", "GitHub", "commit"], ["notes", "Notes", "sticky_note_2"], ["image", "Picture", "image"],
        ["user", "You", "account_circle"], ["greeting", "Greeting", "waving_hand"], ["notifications", "Notifications", "notifications"]
    ]
    readonly property var faces: ({
        clock: [["digital", "Digital"], ["stacked", "Stacked"], ["analog", "Analog"], ["minimal", "Minimal"], ["stretched", "Stretched"],
                ["big", "Big (lock screen)"], ["material", "Material"], ["materialAnalog", "Material analog"], ["lumen", "Lumen"]],
        date: [["full", "Full"], ["compact", "Compact"]],
        weather: [["pill", "Pill"], ["full", "With hours"], ["round", "Round"]],
        media: [["card", "Card"], ["cover", "Cover"], ["controls", "Controls"], ["lyrics", "Lyrics"], ["lyricLine", "Lyrics, one line"], ["round", "Round"]],
        visualizer: [["bars", "Bars"], ["wave", "Wave"]],
        calendar: [["month", "Month"]],
        usage: [["rings", "Rings"], ["bars", "Bars"]],
        cpu: [["number", "Number"], ["circle", "Circle"], ["card", "Card"]],
        ram: [["number", "Number"], ["circle", "Circle"], ["card", "Card"]],
        temp: [["number", "Number"], ["circle", "Circle"], ["card", "Card"]],
        disk: [["number", "Number"], ["circle", "Circle"], ["card", "Card"]],
        battery: [["card", "Card"], ["circle", "Circle"]],
        github: [["grid", "Contributions"]],
        notes: [["card", "Card"]],
        image: [["rounded", "Rounded"], ["circle", "Circle"], ["rect", "Square corners"]],
        user: [["card", "Card"]],
        greeting: [["text", "Text"]],
        notifications: [["list", "List"]]
    })
    // ready-made arrangements (the old Monolith's presets): [id, name, icon, items as [type, face, x, y]]
    readonly property var presets: [
        ["dashboard", "Dashboard", "space_dashboard", [["clock", "digital", 0.04, 0.06], ["weather", "full", 0.04, 0.36], ["calendar", "month", 0.78, 0.06],
            ["cpu", "circle", 0.04, 0.62], ["ram", "circle", 0.14, 0.62], ["disk", "circle", 0.24, 0.62], ["media", "controls", 0.74, 0.78], ["github", "grid", 0.36, 0.80]]],
        ["media", "Media station", "queue_music", [["media", "round", 0.06, 0.30], ["media", "lyrics", 0.30, 0.34], ["visualizer", "bars", 0.30, 0.74], ["clock", "minimal", 0.06, 0.08]]],
        ["minimal", "Minimal", "crop_free", [["clock", "big", 0.36, 0.30], ["date", "compact", 0.43, 0.56]]],
        ["shadow", "Shadow", "dark_mode", [["clock", "stretched", 0.05, 0.08], ["media", "lyricLine", 0.05, 0.82], ["weather", "round", 0.86, 0.08], ["battery", "circle", 0.86, 0.36]]]
    ]
    function applyPreset(mode, id, screen) {
        const p = presets.find(x => x[0] === id);
        if (!p) return;
        const keep = mode === "lock" ? [] : items(mode).filter(i => i.screen && i.screen !== screen);
        save(mode, keep.concat(p[3].map((it, n) => ({ id: it[0][0] + Date.now().toString(36) + n, type: it[0], face: it[1], x: it[2], y: it[3], scale: 1, screen: mode === "lock" ? "" : screen }))));
    }
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
