pragma Singleton
import QtQuick
import Quickshell

// Widget layouts: the desktop's (per screen) and the lock screen's. Each item is
// { id, type, face, x, y, w, h, screen, opts } with x/y as fractions of the screen (its top-left),
// w/h in pixels and opts its own settings (opacity, the ring's style, the text, …).
// The widget editor (wall/WidgetEditor.qml) changes them; Widgets.qml and the lock screen draw them.
Singleton {
    id: wl

    // every widget there is: name, icon, default size, size limits [minW, minH, maxW, maxH],
    // width/height limits [min, max], and its looks [face, name, file in wall/faces, own aspect]
    readonly property var spec: ({
        clock: { name: "Clock", icon: "schedule", size: [300, 140], lim: [80, 40, 1400, 900], aspect: [0.7, 5],
            faces: [["digital", "Digital", "ClockDigital", [1.2, 5]], ["minimal", "Minimal", "ClockMinimal", [1.2, 5]], ["analog", "Analog", "ClockAnalog", [1, 1], [220, 220]],
                    ["material", "Material", "ClockMaterial", [0.7, 1.3], [230, 230]], ["materialAnalog", "Material analog", "ClockMaterialAnalog", [1, 1], [230, 230]],
                    ["lumen", "Lumen", "ClockLumen", [1, 1], [240, 240]], ["lockscreen", "Lock screen", "ClockLockscreen", [0.6, 4], [520, 260]],
                    ["stretched", "Stretched", "ClockStretched", [0.3, 2.5], [300, 280]], ["stacked", "Stacked", "ClockStacked", [0.5, 1.2], [180, 260]]] },
        date: { name: "Date", icon: "today", size: [300, 100], lim: [100, 40, 900, 400], aspect: [1, 6],
            faces: [["full", "Full", "DateFull"], ["compact", "Compact", "DateCompact"]] },
        weather: { name: "Weather", icon: "partly_cloudy_day", size: [250, 120], lim: [90, 70, 800, 500], aspect: [0.8, 4],
            faces: [["compact", "Compact", "WeatherCompact", [0.8, 3.5]], ["full", "Full", "WeatherFull", [1.6, 3.5], [400, 170]], ["round", "Round", "WeatherRound", [1, 1], [200, 200]]] },
        media: { name: "Music", icon: "music_note", size: [360, 130], lim: [120, 60, 1200, 700], aspect: [0.8, 6],
            faces: [["full", "Full", "MusicFull", [2.4, 4.4], [400, 140]], ["round", "Round", "MusicRound", [0.8, 1.25], [300, 300]], ["lyrics", "Lyrics", "MusicLyrics", [0.8, 4], [460, 240]],
                    ["simpleLyrics", "Simple lyrics", "MusicLyricsSimple", [1, 8], [600, 130]], ["cover", "Cover", "MusicCover", [0.8, 1.25], [220, 220]], ["controls", "Controls", "MusicControls", [2, 4], [380, 160]]] },
        visualizer: { name: "Visualiser", icon: "graphic_eq", size: [900, 180], lim: [160, 40, 3840, 600], aspect: [1, 20],
            faces: [["bars", "Bars", "VisualizerBars"], ["continuous", "Continuous", "VisualizerContinuous"]] },
        calendar: { name: "Calendar", icon: "calendar_month", size: [270, 250], lim: [200, 190, 600, 560], aspect: [0.8, 1.6],
            faces: [["month", "Month", "CalendarMonth"]] },
        usage: { name: "System usage", icon: "monitoring", size: [330, 120], lim: [200, 90, 900, 400], aspect: [1.2, 4],
            faces: [["rings", "Rings", "UsageRings"], ["bars", "Bars", "UsageBars", [1, 3], [300, 170]]] },
        cpu: { name: "CPU", icon: "developer_board", size: [180, 130], lim: [90, 70, 600, 600], aspect: [0.6, 2.5],
            faces: [["default", "Card", "MetricCard"], ["circle", "Circle", "MetricCircle", [1, 1], [150, 150]]] },
        ram: { name: "Memory", icon: "memory_alt", size: [180, 130], lim: [90, 70, 600, 600], aspect: [0.6, 2.5],
            faces: [["default", "Card", "MetricCard"], ["circle", "Circle", "MetricCircle", [1, 1], [150, 150]]] },
        temp: { name: "Temperature", icon: "device_thermostat", size: [180, 130], lim: [90, 70, 600, 600], aspect: [0.6, 2.5],
            faces: [["default", "Card", "MetricCard"], ["circle", "Circle", "MetricCircle", [1, 1], [150, 150]]] },
        disk: { name: "Disk", icon: "hard_drive", size: [180, 130], lim: [90, 70, 600, 600], aspect: [0.6, 2.5],
            faces: [["default", "Card", "MetricCard"], ["circle", "Circle", "MetricCircle", [1, 1], [150, 150]]] },
        battery: { name: "Battery", icon: "battery_full", size: [260, 90], lim: [90, 60, 600, 600], aspect: [0.6, 4.5],
            faces: [["default", "Bar", "BatteryBar", [1.5, 4.5]], ["circle", "Circle", "BatteryCircle", [1, 1], [150, 150]]] },
        github: { name: "GitHub", icon: "commit", size: [560, 190], lim: [320, 150, 1100, 320], aspect: [2, 5],
            faces: [["default", "Contributions", "GithubGrid"]] },
        notes: { name: "Notes", icon: "sticky_note_2", size: [300, 280], lim: [200, 160, 700, 700], aspect: [0.5, 2.5],
            faces: [["default", "Card", "NotesCard"]] },
        text: { name: "Text", icon: "text_fields", size: [320, 90], lim: [60, 30, 1600, 600], aspect: [0.3, 12],
            faces: [["default", "Text", "TextPlain"]] },
        image: { name: "Picture", icon: "image", size: [300, 200], lim: [60, 60, 1600, 1200], aspect: [0.25, 4],
            faces: [["rounded", "Rounded", "ImageRounded"], ["rect", "Square corners", "ImageRect"], ["round", "Round", "ImageRound", [1, 1], [200, 200]]] },
        user: { name: "You", icon: "account_circle", size: [280, 150], lim: [220, 120, 600, 300], aspect: [1.4, 3],
            faces: [["default", "Card", "UserCard"]] },
        greeting: { name: "Greeting", icon: "waving_hand", size: [460, 100], lim: [160, 50, 1400, 400], aspect: [1.5, 8],
            faces: [["text", "Text", "GreetingText"]] },
        notifications: { name: "Notifications", icon: "notifications", size: [360, 190], lim: [240, 80, 700, 600], aspect: [0.8, 5],
            faces: [["list", "List", "NotificationsList"]] }
    })
    // the order they're offered in
    readonly property var order: ["clock", "date", "weather", "media", "visualizer", "calendar", "usage", "cpu", "ram", "temp", "disk",
        "battery", "github", "notes", "text", "image", "user", "greeting", "notifications"]
    // [type, name, icon] for the add palette, and each type's [face, name] for the style drop-downs
    readonly property var types: order.map(t => [t, spec[t].name, spec[t].icon])
    readonly property var faces: {
        const o = {};
        for (const t of order) o[t] = spec[t].faces.map(f => [f[0], f[1]]);
        return o;
    }
    function typeName(t) { return spec[t] ? spec[t].name : t; }
    function typeIcon(t) { return spec[t] ? spec[t].icon : "widgets"; }
    function faceName(t, f) { const x = faceOf(t, f); return x ? x[1] : "Default"; }

    // looks saved by earlier versions, under their new names
    readonly property var renamed: ({ "clock/big": "lockscreen", "weather/pill": "compact", "media/card": "full", "media/lyricLine": "simpleLyrics",
        "visualizer/wave": "continuous", "cpu/number": "default", "cpu/card": "default", "ram/number": "default", "ram/card": "default",
        "temp/number": "default", "temp/card": "default", "disk/number": "default", "disk/card": "default", "battery/card": "default",
        "github/grid": "default", "notes/card": "default", "user/card": "default", "image/circle": "round" })
    function faceOf(t, f) {
        const s = spec[t];
        if (!s) return null;
        const name = renamed[t + "/" + f] || f;
        return s.faces.find(x => x[0] === name) || s.faces[0];
    }
    function file(t, f) { const x = faceOf(t, f); return x ? x[2] : ""; }
    function faceId(t, f) { const x = faceOf(t, f); return x ? x[0] : ""; }

    // an item's size: its own, else the default (times the old scale)
    function size(it) {
        const s = spec[it.type];
        if (!s) return [200, 100];
        if (it.w > 0 && it.h > 0) return clamp(it.type, it.face, it.w, it.h);
        const k = it.scale || 1;
        const a = aspectOf(it.type, it.face);
        const fd = faceOf(it.type, it.face);
        const base = fd && fd[4] ? fd[4] : s.size;
        let w = base[0] * k, h = base[1] * k;
        // a round look on a wide default: make it square-ish
        if (w / h > a[1]) w = h * a[1];
        if (w / h < a[0]) h = w / a[0];
        return clamp(it.type, it.face, w, h);
    }
    // each look's own limits, as the old widgets had them: [minW, minH, maxW, maxH, min w/h, max w/h]
    // (a look missing here uses its widget's limits and shape)
    readonly property var looks: ({
        "clock/digital": [120, 60, 1400, 700, 1.2, 5], "clock/minimal": [80, 40, 1200, 600, 1.2, 5],
        "clock/analog": [100, 100, 800, 800, 1, 1], "clock/materialAnalog": [100, 100, 800, 800, 1, 1],
        "clock/lumen": [100, 100, 800, 800, 1, 1], "clock/material": [100, 100, 900, 900, 0.7, 1.3],
        "clock/lockscreen": [160, 80, 1600, 800, 0.8, 2.8], "clock/stretched": [100, 120, 900, 1200, 0.3, 2.5],
        "weather/compact": [90, 90, 600, 600, 0.7, 2.2], "weather/full": [340, 160, 820, 500, 1.5, 2.2], "weather/round": [90, 90, 600, 600, 1, 1],
        "media/full": [150, 64, 800, 300, 2.4, 4.4], "media/round": [150, 150, 1000, 1000, 1, 1],
        "media/lyrics": [180, 60, 1200, 600, 1.2, 5], "media/simpleLyrics": [180, 60, 2400, 1200, 0.5, 8],
        "visualizer/bars": [50, 50, 3840, 1200, 0.1, 80], "visualizer/continuous": [50, 50, 3840, 1200, 0.1, 80],
        "cpu/default": [100, 70, 600, 400, 0.6, 3], "ram/default": [100, 70, 600, 400, 0.6, 3],
        "temp/default": [100, 70, 600, 400, 0.6, 3], "disk/default": [100, 70, 600, 400, 0.6, 3],
        "cpu/circle": [90, 90, 600, 600, 0.5, 2], "ram/circle": [90, 90, 600, 600, 0.5, 2],
        "temp/circle": [90, 90, 600, 600, 0.5, 2], "disk/circle": [90, 90, 600, 600, 0.5, 2],
        "battery/default": [160, 60, 600, 200, 1.5, 4.5], "battery/circle": [90, 90, 600, 600, 0.5, 2],
        "github/default": [520, 140, 1200, 380, 1.4, 8.5], "notes/default": [240, 180, 700, 700, 0.5, 2.5],
        "text/default": [60, 30, 2000, 800, 0.2, 20], "image/rect": [30, 30, 4000, 4000, 0.02, 50],
        "image/rounded": [30, 30, 4000, 4000, 0.02, 50], "image/round": [40, 40, 3000, 3000, 1, 1],
        "user/default": [220, 130, 500, 300, 1.2, 2.8]
    })
    function lookOf(t, f) { return looks[t + "/" + faceId(t, f)] || null; }
    function aspectOf(t, f) {
        const l = lookOf(t, f);
        if (l) return [l[4], l[5]];
        const x = faceOf(t, f); return x && x[3] ? x[3] : (spec[t] ? spec[t].aspect : [0.2, 10]);
    }
    function limOf(t, f) { const l = lookOf(t, f); return l ? l.slice(0, 4) : (spec[t] ? spec[t].lim : [40, 40, 4000, 4000]); }
    // keep a size inside the look's limits and shape
    function clamp(t, f, w, h) {
        const s = spec[t];
        if (!s) return [w, h];
        const a = aspectOf(t, f);
        const lim = limOf(t, f);
        w = Math.max(lim[0], Math.min(lim[2], w));
        h = Math.max(lim[1], Math.min(lim[3], h));
        if (w / h > a[1]) w = h * a[1];
        if (w / h < a[0]) h = w / a[0];
        return [Math.round(w), Math.round(h)];
    }

    // each widget's own settings, shown in the editor for the selected one:
    // [key, label, kind ("toggle" | "slider" | "choice" | "text" | "file"), default, extra]
    function optionsFor(t, f) {
        const id = faceId(t, f);
        const o = [["opacity", "Opacity", "slider", 1, [0.15, 1, 0.05]]];
        if (["cpu", "ram", "temp", "disk", "battery"].indexOf(t) !== -1 && id === "circle")
            o.push(["sineWave", "Wavy ring", "toggle", true], ["lineThickness", "Line thickness", "slider", 8, [3, 16, 1]]);
        if (t === "media" && (id === "lyrics" || id === "simpleLyrics"))
            o.push(["lyricsLines", "Lines before and after", "slider", id === "lyrics" ? 2 : 1, [0, 4, 1]], ["lyricsAlignment", "Alignment", "choice", "left", [["left", "Left"], ["center", "Centre"], ["right", "Right"]]],
                   ["showNoLyrics", "Say when there are no lyrics", "toggle", true]);
        if (t === "media" && id === "full")
            o.push(["showBars", "Visualiser behind it", "toggle", true], ["continuous", "Smooth visualiser", "toggle", false]);
        if (t === "clock" && (id === "analog" || id === "materialAnalog" || id === "lumen"))
            o.push(["showSeconds", "Seconds hand", "toggle", true]);
        if (t === "text") o.push(["textContent", "Text", "text", ""]);
        if (t === "image") o.push(["imagePath", "Picture", "file", ""]);
        if (t === "github") o.push(["store:widgets.github.user", "GitHub username", "text", ""]);
        if (t === "visualizer") o.push(["mirror", "Mirrored (from the middle)", "toggle", false]);
        return o;
    }
    function opt(it, key, fallback) { return it && it.opts && it.opts[key] !== undefined ? it.opts[key] : fallback; }

    // what's there to start with: the desktop keeps the earlier widgets you had on; the lock
    // screen gets a clock, notifications and now playing
    readonly property var desktopDefault: {
        const old = [["clock", 0.05, 0.62], ["weather", 0.05, 0.84], ["media", 0.72, 0.84], ["calendar", 0.80, 0.08], ["usage", 0.05, 0.08], ["notes", 0.80, 0.42], ["image", 0.42, 0.08]];
        const on = { clock: true, weather: true, media: true };
        return old.filter(o => Store.get("widgets.hidden." + o[0], !on[o[0]]) !== true)
                  .map((o, i) => ({ id: "d" + i, type: o[0], face: "", x: o[1], y: o[2], screen: "" }));
    }
    readonly property var lockDefault: [
        { id: "l0", type: "clock", face: "lockscreen", x: 0.36, y: 0.12, w: 520, h: 300, screen: "" },
        { id: "l2", type: "notifications", face: "list", x: 0.03, y: 0.72, screen: "" },
        { id: "l3", type: "media", face: "full", x: 0.72, y: 0.82, screen: "" }
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
    function setOpt(mode, id, k, v) {
        save(mode, items(mode).map(i => {
            if (i.id !== id) return i;
            const o = Object.assign({}, i.opts || {});
            o[k] = v;
            return Object.assign({}, i, { opts: o });
        }));
    }
    function remove(mode, id) { save(mode, items(mode).filter(i => i.id !== id)); }
    // the add strip's categories: [id, name, icon, types]
    readonly property var categories: [
        ["all", "All", "apps", order],
        ["time", "Time", "schedule", ["clock", "date", "calendar"]],
        ["media", "Media", "music_note", ["media", "visualizer", "image"]],
        ["system", "System", "monitoring", ["usage", "cpu", "ram", "temp", "disk", "battery"]],
        ["info", "Info", "info", ["weather", "notifications", "github"]],
        ["you", "Personal", "person", ["user", "greeting", "notes", "text"]]
    ]
    // x/y: where its top-left goes, as fractions of the screen (else near the middle)
    function add(mode, type, screen, x, y) {
        const id = type[0] + Date.now().toString(36);
        const s = spec[type];
        const d = s ? (s.faces[0][4] || s.size) : [0, 0];
        save(mode, items(mode).concat([{ id: id, type: type, face: "", x: x === undefined ? 0.4 : x, y: y === undefined ? 0.4 : y, w: d[0], h: d[1], screen: mode === "lock" ? "" : screen }]));
        return id;
    }
    // a new look: its own default size when it has one (a round look), else the size kept inside its shape
    function setFace(mode, it, face) {
        const fd = faceOf(it.type, face);
        const sz = fd && fd[4] ? fd[4] : size(Object.assign({}, it, { face: face }));
        update(mode, it.id, { face: face, w: sz[0], h: sz[1] });
    }
    function reset(mode) { Store.set(key(mode), null); }

    // ready-made arrangements (the old Monolith's presets): [id, name, icon, items as [type, face, x, y, w, h]]
    readonly property var presets: [
        ["dashboard", "Dashboard", "space_dashboard", [["clock", "digital", 0.04, 0.06, 380, 160], ["weather", "full", 0.04, 0.30, 380, 150], ["calendar", "month", 0.80, 0.06, 280, 260],
            ["cpu", "circle", 0.04, 0.55, 150, 150], ["ram", "circle", 0.13, 0.55, 150, 150], ["disk", "circle", 0.22, 0.55, 150, 150], ["media", "full", 0.70, 0.80, 420, 140], ["github", "default", 0.33, 0.78, 560, 190]]],
        ["media", "Media station", "queue_music", [["media", "round", 0.06, 0.28, 360, 360], ["media", "lyrics", 0.32, 0.30, 520, 300], ["visualizer", "bars", 0.06, 0.78, 1500, 160], ["clock", "minimal", 0.06, 0.06, 260, 100]]],
        ["minimal", "Minimal", "crop_free", [["clock", "lockscreen", 0.33, 0.28, 600, 320]]],
        ["shadow", "Shadow", "dark_mode", [["clock", "stretched", 0.05, 0.08, 620, 170], ["media", "simpleLyrics", 0.05, 0.80, 700, 120], ["weather", "round", 0.88, 0.08, 110, 220], ["battery", "circle", 0.86, 0.45, 150, 150]]]
    ]
    function applyPreset(mode, id, screen) {
        const p = presets.find(x => x[0] === id);
        if (!p) return;
        const keep = mode === "lock" ? [] : items(mode).filter(i => i.screen && i.screen !== screen);
        save(mode, keep.concat(p[3].map((it, n) => ({ id: it[0][0] + Date.now().toString(36) + n, type: it[0], face: it[1], x: it[2], y: it[3], w: it[4], h: it[5], screen: mode === "lock" ? "" : screen }))));
    }
}
