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
        for (const b of held) {
            const k = keysFor(b.mods, b.key);
            // (cleared first, so putting one back never doubles one that's already there: after a
            // config reload, say)
            if (hm.lua) evalLua("hl.unbind(" + JSON.stringify(k.join(" + ")) + ")");
            else keyword("unbind", k.slice(0, -1).join(" ") + "," + b.key);
            if (hm.lua)
                evalLua("hl.bind(" + JSON.stringify(k.join(" + ")) + ", " + (b.what === "resize" ? "hl.dsp.window.resize()" : "hl.dsp.window.drag()") + ", { mouse = true })");
            else keyword("bindm", k.slice(0, -1).join(" ") + "," + b.key + "," + (b.what === "resize" ? "resizewindow" : "movewindow"));
        }
        held = [];
        Store.set("hypr.mouseHeld", []);
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
