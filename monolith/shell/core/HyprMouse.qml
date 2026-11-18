pragma Singleton
import QtQuick
import Quickshell
import Quickshell.Io

// Hyprland: while a Monolith menu is open, the mouse bindings that drag or resize windows
// (Super + left / right button, or whatever yours are) are switched off, and put back as they
// were when it closes. Hyprland hands those to the window under the pointer even when a menu is
// over it, so Super + click on a menu grabbed the window behind instead. (niri doesn't: it lets
// a shell surface on top have the click.) It reads the live bindings each time, so your own work
// as well as Monolith's, and remembers what it switched off, so a shell that stops mid-menu puts
// them back when it starts again.
Singleton {
    id: hm
    readonly property bool wanted: Niri.hyprland && (HubState.open || HubState.wallOpen)
    // what's switched off now: [{ mods, key, what }] (what: "move" | "resize")
    property var held: []
    property bool busy: false
    // a Lua config (hyprland.lua): its binds come back as HL.Dispatcher(…), and it takes
    // hl.unbind / hl.bind; an old one takes `hyprctl keyword`
    property bool lua: Niri.hyprLua

    onWantedChanged: Qt.callLater(apply)
    function apply() {
        if (busy) return;
        if (wanted && held.length === 0) { busy = true; read.running = true; }
        else if (!wanted && held.length > 0) restore();
    }

    // Hyprland's modifier mask as the keys Hyprland's config takes
    function keysFor(mask, key) {
        const m = [];
        if (mask & 64) m.push("SUPER");
        if (mask & 4) m.push("CTRL");
        if (mask & 8) m.push("ALT");
        if (mask & 1) m.push("SHIFT");
        return m.concat([key]);
    }
    function evalLua(code) { Quickshell.execDetached(["hyprctl", "eval", code]); }
    function keyword(a, b) { Quickshell.execDetached(["hyprctl", "keyword", a, b]); }

    function switchOff(list) {
        for (const b of list) {
            const k = keysFor(b.mods, b.key);
            if (hm.lua) evalLua("hl.unbind(" + JSON.stringify(k.join(" + ")) + ")");
            else keyword("unbind", k.slice(0, -1).join(" ") + "," + b.key);
        }
    }
    function restore() {
        // (each one cleared and put back in ONE command, in that order: as two commands they
        // could run the other way round, and the binding ended up cleared for good)
        for (const b of held) {
            const k = keysFor(b.mods, b.key);
            if (hm.lua) {
                const keys = JSON.stringify(k.join(" + "));
                evalLua("hl.unbind(" + keys + "); hl.bind(" + keys + ", " + (b.what === "resize" ? "hl.dsp.window.resize()" : "hl.dsp.window.drag()") + ", { mouse = true })");
            } else {
                const mods = k.slice(0, -1).join(" ");
                Quickshell.execDetached(["sh", "-c", "hyprctl keyword unbind \"$1,$2\"; hyprctl keyword bindm \"$1,$2,$3\"", "sh", mods, b.key, b.what === "resize" ? "resizewindow" : "movewindow"]);
            }
        }
        // (looked at again in a moment: see `check`)
        expect = held;
        held = [];
        Store.set("hypr.mouseHeld", []);
        checkLater.restart();
    }
    // A moment after putting them back, look that they're really there, and put back any that
    // aren't: opening and closing a menu at once could run the "off" after the "back on".
    property var expect: []
    property int tries: 0
    Timer { id: checkLater; interval: 700; onTriggered: if (!hm.wanted && hm.held.length === 0 && hm.expect.length > 0) check.running = true }
    Process {
        id: check
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                if (hm.wanted || hm.held.length > 0) return;
                let have = [];
                try { have = JSON.parse(text).filter(b => b.mouse).map(b => (Number(b.modmask) || 0) + "|" + b.key); } catch (e) { return; }
                const missing = hm.expect.filter(b => have.indexOf(b.mods + "|" + b.key) < 0);
                if (!missing.length) { hm.expect = []; hm.tries = 0; return; }
                // (a few times at most: one that Hyprland won't take isn't tried for ever)
                if (++hm.tries > 3) { hm.expect = []; hm.tries = 0; return; }
                hm.held = missing;
                hm.restore();
            }
        }
    }

    Process {
        id: read
        command: ["hyprctl", "binds", "-j"]
        stdout: StdioCollector {
            onStreamFinished: {
                hm.busy = false;
                if (!hm.wanted) return;
                let list = [];
                try {
                    for (const b of JSON.parse(text)) {
                        const key = String(b.key || "");
                        if (!b.mouse || (key !== "mouse:272" && key !== "mouse:273")) continue;
                        const d = String(b.dispatcher || "") + " " + String(b.arg || "");
                        const what = /resize/i.test(d) ? "resize" : (/move|drag/i.test(d) ? "move" : "");
                        // (once each: a binding listed twice is one to put back)
                        if (what && !list.some(x => x.mods === (Number(b.modmask) || 0) && x.key === key))
                            list.push({ mods: Number(b.modmask) || 0, key: key, what: what });
                        if (/^HL\./.test(String(b.dispatcher || ""))) hm.lua = true;
                    }
                } catch (e) { list = []; }
                if (!list.length) return;
                hm.held = list;
                Store.set("hypr.mouseHeld", list.map(b => Object.assign({ lua: hm.lua }, b)));
                hm.switchOff(list);
            }
        }
    }

    // put back what a shell that stopped mid-menu had switched off
    // (a moment after start: the settings and whether Hyprland's config is Lua are read first)
    Timer {
        interval: 2500
        running: Niri.hyprland && Store.loaded
        onTriggered: {
            const left = Store.get("hypr.mouseHeld", []) || [];
            if (left.length && hm.held.length === 0 && !hm.wanted) { hm.lua = left[0].lua !== undefined ? left[0].lua === true : hm.lua; hm.held = left; hm.restore(); }
        }
    }
}
