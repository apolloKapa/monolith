pragma Singleton
import QtQuick
import Quickshell

// Interface sounds (Settings → Sound → Sounds): short blips for clicks, switches, menus,
// dropping things, volume steps, workspaces, screenshots, locking and wallpapers. Made by
// tools/make_sounds.py in packs (sounds/<pack>/<event>.wav, each its own voice), or your own
// folder with files of the same names. Played with pw-play as "event" sounds at their own volume.
// Off unless switched on; each kind can be switched off on its own (sounds.events).
Singleton {
    id: snd
    readonly property bool on: Store.get("sounds.enabled", false) === true
    readonly property real volume: Math.max(0, Math.min(1, Number(Store.get("sounds.volume", 0.5))))
    readonly property string base: Qt.resolvedUrl("../sounds").toString().replace(/^file:\/\//, "")
    // the packs that come with Monolith: [id, name, what it sounds like]
    readonly property var packs: [
        ["soft", "Soft", "Rounded little blips"],
        ["glass", "Glass", "Bell-like, ringing a little longer"],
        ["pop", "Pop", "Quick bubbly drops"],
        ["retro", "Retro", "8-bit square waves"],
        ["wood", "Wood", "Short wooden knocks"],
        ["custom", "Your own folder", "Your own .wav files"]
    ]
    readonly property string pack: Store.get("sounds.pack", "soft")
    readonly property string customDir: (Store.get("sounds.customDir", "") || "").replace(/^~/, Quickshell.env("HOME"))
    readonly property string dir: pack === "custom" && customDir !== "" ? customDir : base + "/" + (pack === "custom" ? "soft" : pack)
    // the kinds, each with its sounds: [id, name, sounds…]
    readonly property var kinds: [
        ["clicks", "Clicks", "click"],
        ["switches", "Switches", "toggle-on", "toggle-off"],
        ["menus", "Menus opening and closing", "open", "close"],
        ["drops", "Dragging and dropping", "drop"],
        ["volume", "Volume and brightness steps", "tick"],
        ["workspaces", "Switching workspaces", "workspace"],
        ["screenshots", "Screenshots", "shutter"],
        ["lock", "Locking and unlocking", "lock", "unlock"],
        ["wallpaper", "Wallpaper changes", "wallpaper"],
        ["errors", "Something went wrong (a wrong password)", "error"]
    ]
    readonly property var events: Store.get("sounds.events", ({})) || ({})
    function kindOf(name) { const k = kinds.find(k => k.indexOf(name, 2) !== -1); return k ? k[0] : ""; }
    function kindOn(kind) { return events[kind] !== false; }
    // a burst of clicks plays once
    property real last: 0
    function play(name) {
        if (!on || volume <= 0 || !kindOn(kindOf(name))) return;
        const now = Date.now();
        if (now - last < 40) return;
        last = now;
        playFile(dir + "/" + name + ".wav", volume);
    }
    // the pack's own sound, whether interface sounds are on or not (the notification sound can use it)
    function playAlways(name) { playFile(dir + "/" + name + ".wav", Math.max(0.05, volume)); }
    function playFile(f, v) {
        Quickshell.execDetached(["pw-play", "--media-role", "Notification", "--volume", String(v),
            "-P", "{ \"application.name\": \"Monolith sounds\", \"media.role\": \"event\" }", f]);
    }
    // a little tune of the pack (Settings: hearing it)
    function demo(p) {
        const d = p === "custom" ? (customDir || base + "/soft") : base + "/" + p;
        Quickshell.execDetached(["sh", "-c", "for s in open toggle-on click close; do pw-play --volume \"$2\" \"$1/$s.wav\"; done", "_", d, String(Math.max(0.1, volume))]);
    }
}
