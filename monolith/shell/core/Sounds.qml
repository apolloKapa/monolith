pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.UPower

// Sound effects (Settings → Sound → Sound effects): short sounds for clicks, switches, menus,
// typing in Monolith's fields, windows opening and closing, apps starting, workspaces, volume
// steps, screenshots, locking, wallpapers, notifications going, the charger… Real recordings
// (Kenney's Interface Sounds and UI Audio, CC0: sounds/CREDITS.txt), picked and levelled per pack
// by tools/make_sounds_recorded.py (sounds/<pack>/<event>.wav, each its own character), or your own
// folder with files of the same names. Off unless switched on; every event can be switched off on
// its own (sounds.events).
//
// Played by Qt's own audio (QtMultimedia's SoundEffect: no process for every keystroke, and no
// pw-play needed), or, where that isn't there or has no sound server to talk to, by
// scripts/play.sh with whatever player the system has (pw-play, paplay, ffplay, aplay).
Singleton {
    id: snd
    readonly property bool on: Store.get("sounds.enabled", false) === true
    readonly property real volume: Math.max(0, Math.min(1, Number(Store.get("sounds.volume", 0.5))))
    readonly property string base: Qt.resolvedUrl("../sounds").toString().replace(/^file:\/\//, "")
    readonly property string player: Qt.resolvedUrl("../scripts/play.sh").toString().replace(/^file:\/\//, "")
    // the packs that come with Monolith: [id, name, what it sounds like]
    readonly property var packs: [
        ["soft", "Soft", "Quiet real switches and mouse clicks"],
        ["glass", "Glass", "Glass taps, ticks and plucks"],
        ["pop", "Pop", "Drops and quick plucks"],
        ["wood", "Wood", "Dull knocks, thumps and low switches"],
        ["custom", "Your own folder", "Your own .wav files"]
    ]
    // (a pack that's gone, Retro or Cyberpunk, removed in 2.9.66: Soft)
    readonly property string chosen: packs.some(p => p[0] === Store.get("sounds.pack", "soft")) ? Store.get("sounds.pack", "soft") : "soft"
    // a style with its own sounds (styles.js `sounds`, none now) plays them instead
    // of the pack you picked, unless you switch that off (sounds.followStyle)
    readonly property string stylePack: Look.style.sounds || ""
    readonly property bool followStyle: Store.get("sounds.followStyle", true) !== false
    readonly property string pack: followStyle && stylePack !== "" ? stylePack : chosen
    readonly property string customDir: (Store.get("sounds.customDir", "") || "").replace(/^~/, Quickshell.env("HOME"))
    readonly property string dir: pack === "custom" && customDir !== "" ? customDir : base + "/" + (pack === "custom" ? "soft" : pack)

    // ── the events: [id, group, name, icon, what makes it] ──
    readonly property var groups: [
        ["clicking", "Clicking around"],
        ["menus", "Menus and typing"],
        ["windows", "Windows and apps"],
        ["notifications", "Notifications"],
        ["system", "The system"]
    ]
    readonly property var list: [
        ["click", "clicking", "Clicks", "ads_click", "Buttons, rows and tiles in Monolith"],
        ["toggle-on", "clicking", "Switching on", "toggle_on", "A switch going on"],
        ["toggle-off", "clicking", "Switching off", "toggle_off", "A switch going off"],
        ["drop", "clicking", "Dropping", "drag_pan", "Dropping a widget in the widget editor"],
        ["open", "menus", "Opening a menu", "menu_open", "The control center, search, Settings…"],
        ["close", "menus", "Closing a menu", "close", "Any of them going away"],
        ["type", "menus", "Typing", "keyboard", "Each key in Monolith's fields: search, Settings, notes, the lock screen…"],
        ["erase", "menus", "Erasing", "backspace", "Backspace and Delete in those fields"],
        ["window-open", "windows", "A window opening", "open_in_new", "Any app's window appearing"],
        ["window-close", "windows", "A window closing", "close_fullscreen", "Any app's window going away"],
        ["launch", "windows", "Starting an app", "rocket_launch", "From search or the dock"],
        ["workspace", "windows", "Switching workspaces", "view_carousel", "Moving to another workspace"],
        ["dismiss", "notifications", "Dismissing a notification", "notifications_off", "Closing or swiping one away"],
        ["tick", "system", "Volume and brightness steps", "volume_up", "Each step of the keys"],
        ["shutter", "system", "Screenshots", "screenshot_region", "Taking a picture of the screen"],
        ["lock", "system", "Locking", "lock", "The lock screen coming up"],
        ["unlock", "system", "Unlocking", "lock_open", "The right password"],
        ["error", "system", "Something went wrong", "error", "A wrong password, a switch that couldn't change"],
        ["wallpaper", "system", "Wallpaper changes", "wallpaper", "A new wallpaper"],
        ["plug", "system", "Charger plugged in", "power", "Laptops: the charger going in"],
        ["unplug", "system", "Charger unplugged", "power_off", "Laptops: the charger coming out"]
    ]
    // (the switches before there was one for every event: a kind covered a few)
    readonly property var legacy: ({ click: "clicks", "toggle-on": "switches", "toggle-off": "switches", open: "menus", close: "menus", drop: "drops", tick: "volume", workspace: "workspaces", shutter: "screenshots", lock: "lock", unlock: "lock", wallpaper: "wallpaper", error: "errors" })
    // how loud each is next to the others (typing is quiet: it's many)
    readonly property var gain: ({ type: 0.45, erase: 0.45, tick: 0.8 })
    readonly property var events: Store.get("sounds.events", ({})) || ({})
    function eventOn(name) {
        if (events[name] !== undefined) return events[name] !== false;
        const k = legacy[name];
        return !(k && events[k] === false);
    }
    function setEvent(name, v) { const e = Object.assign({}, events); e[name] = v; Store.set("sounds.events", e); }
    function setGroup(g, v) {
        const e = Object.assign({}, events);
        for (const ev of list) if (ev[1] === g) e[ev[0]] = v;
        Store.set("sounds.events", e);
    }

    // a burst of the same sound plays once
    property var last: ({})
    function play(name) {
        if (!on || volume <= 0 || !eventOn(name)) return;
        const now = Date.now();
        if (now - (last[name] || 0) < 35) return;
        last[name] = now;
        playFile(dir + "/" + name + ".wav", volume * (gain[name] || 1));
    }
    // the pack's own sound, whether sound effects are on or not (the notification sound can use it)
    function playAlways(name) { playFile(dir + "/" + name + ".wav", Math.max(0.05, volume)); }
    // a key in one of Monolith's fields (Keys.onPressed: e => Sounds.key(e)); never accepts it
    function key(e) {
        if (e.key === Qt.Key_Backspace || e.key === Qt.Key_Delete) play("erase");
        else if (e.text && e.text.length > 0 && e.text.charCodeAt(0) >= 32 && !(e.modifiers & (Qt.ControlModifier | Qt.MetaModifier))) play("type");
    }

    // ── playing ──
    // "auto": Qt's audio when there's a sound server for it, else play.sh; "qt"; "system" (play.sh)
    readonly property string how: Store.get("sounds.player", "auto")
    // ok (a PipeWire or PulseAudio server answers: Qt talks to either), none, unknown (no tool to ask)
    property string probe: ""
    property string systemPlayer: "" // what play.sh would use ("" = nothing)
    readonly property bool useQt: qtOk && (how === "qt" || (how === "auto" && probe !== "none"))
    readonly property string engine: useQt ? "Qt (QtMultimedia)" : (systemPlayer !== "" ? systemPlayer : "")
    property bool qtOk: true
    Process {
        id: prober
        running: true
        command: ["sh", "-c", "if command -v pw-cli >/dev/null 2>&1 && timeout 3 pw-cli info 0 >/dev/null 2>&1; then echo ok; "
            + "elif command -v pactl >/dev/null 2>&1 && timeout 3 pactl info >/dev/null 2>&1; then echo ok; "
            + "elif command -v pw-cli >/dev/null 2>&1 || command -v pactl >/dev/null 2>&1; then echo none; else echo unknown; fi; "
            + "sh \"$1\" which", "_", snd.player]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                snd.probe = (l[0] || "unknown").trim();
                snd.systemPlayer = (l[1] || "").trim();
                // (at login the sound server can come up after the shell: ask again in a while)
                if (snd.probe === "none" && reprobes < 6) { reprobes++; reprobe.restart(); }
            }
        }
    }
    property int reprobes: 0
    Timer { id: reprobe; interval: 5000; onTriggered: prober.running = true }

    // a few SoundEffects for each file (fast typing overlaps), made the first time it's played
    property var pools: ({})
    property var turn: ({})
    function effects(f) {
        if (!useQt) return null;
        let pool = pools[f];
        if (pool) return pool;
        pool = [];
        try {
            for (let i = 0; i < 3; i++) {
                const e = Qt.createQmlObject('import QtMultimedia; SoundEffect { property bool wanted: false }', snd, "Sounds");
                e.source = "file://" + f;
                const fe = e, file = f;
                // a file it can't load (or no audio for it): the system player tries instead
                e.statusChanged.connect(() => { if (fe.status === 3 && fe.wanted) { fe.wanted = false; snd.playSystem(file, fe.volume); } });
                pool.push(e);
            }
        } catch (err) {
            console.warn("Sounds: no QtMultimedia (" + err + "), playing with " + (systemPlayer || "nothing"));
            qtOk = false;
            return null;
        }
        pools[f] = pool;
        return pool;
    }
    function playFile(f, v) {
        const pool = effects(f);
        if (!pool) { playSystem(f, v); return; }
        const i = ((turn[f] || 0) + 1) % pool.length;
        turn[f] = i;
        const e = pool[i];
        e.volume = Math.max(0, Math.min(1, v));
        if (e.status === 3) { playSystem(f, v); return; }
        e.wanted = e.status !== 2;   // (still loading: it plays once it's loaded, or falls back)
        e.play();
    }
    function playSystem(f, v, fallback) {
        Quickshell.execDetached(["sh", player, String(Math.max(0, Math.min(1, v))), f, fallback || ""]);
    }
    // stop a long sound (the welcome tour's intro, when it's skipped)
    function stopFile(f) {
        const pool = pools[f];
        if (pool) for (const e of pool) e.stop();
        Quickshell.execDetached(["pkill", "-f", "--", f]);
    }
    // a little tune of the pack (Settings: hearing it)
    property var demoQueue: []
    property string demoDir: ""
    function demo(p) {
        demoDir = p === "custom" ? (customDir || base + "/soft") : base + "/" + p;
        demoQueue = ["open", "toggle-on", "click", "close"];
        demoStep.restart();
        demoStep.triggered();
    }
    Timer {
        id: demoStep; interval: 170; repeat: true
        onTriggered: {
            if (!snd.demoQueue.length) { stop(); return; }
            const q = snd.demoQueue.slice();
            snd.playFile(snd.demoDir + "/" + q.shift() + ".wav", Math.max(0.1, snd.volume));
            snd.demoQueue = q;
        }
    }

    // ── what the shell can't see happening in one place: windows, the charger ──
    // (quiet for a moment after the shell starts: the window list fills in then)
    property bool settled: false
    Timer { interval: 4000; running: true; onTriggered: { snd.winIds = Object.keys(Niri.windows); snd.settled = true; } }
    property var winIds: []
    Connections {
        target: Niri
        function onWindowsChanged() {
            const ids = Object.keys(Niri.windows);
            if (!snd.settled) return;
            const was = snd.winIds;
            const added = ids.filter(k => was.indexOf(k) === -1).length;
            const gone = was.filter(k => ids.indexOf(k) === -1).length;
            snd.winIds = ids;
            // (a whole list changing at once is the compositor reconnecting, not windows)
            if (added > 0 && added <= 2) snd.play("window-open");
            else if (gone > 0 && gone <= 2) snd.play("window-close");
        }
    }
    readonly property bool hasBattery: !!UPower.displayDevice && UPower.displayDevice.isLaptopBattery
    Connections {
        target: UPower
        function onOnBatteryChanged() { if (snd.settled && snd.hasBattery) snd.play(UPower.onBattery ? "unplug" : "plug"); }
    }
}
