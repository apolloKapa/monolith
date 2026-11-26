import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Keyboard (languages, repeat), mouse and touchpad: niri's input config. The keyboard's
// languages and the mouse's scroll speed are set on Hyprland too (scripts/hypr_input.py).
ColumnLayout {
    id: sec
    spacing: 8
    property var v: ({})
    function val(spec, fallback) { const x = v[spec]; return x === null || x === undefined ? fallback : x; }
    function has(spec) { return v[spec] !== null && v[spec] !== undefined; }
    function reload() {
        NiriConf.read(["input/keyboard/xkb|layout", "input/keyboard/xkb|variant", "input/keyboard/xkb|options", "input/keyboard|repeat-delay", "input/keyboard|repeat-rate", "input/keyboard|numlock",
                       "input/mouse|accel-speed", "input/mouse|accel-profile", "input/mouse|natural-scroll", "input/mouse|scroll-factor",
                       "input/touchpad|accel-speed", "input/touchpad|tap", "input/touchpad|natural-scroll", "input/touchpad|dwt"], r => sec.v = r);
    }
    Component.onCompleted: reload()
    Connections { target: NiriConf; function onChanged() { if (Object.keys(sec.pending).length === 0) sec.reload(); } }
    // optimistic: show the new value right away
    // (slider drags write once, a moment after the last move)
    property var pending: ({})
    function put(block, key, value) {
        const c = Object.assign({}, v); c[block + "|" + key] = String(value); v = c;
        const p = Object.assign({}, pending); p[block + "|" + key] = [block, key, value]; pending = p;
        flush.restart();
    }
    Timer { id: flush; interval: 350; onTriggered: { for (const k in sec.pending) NiriConf.set(...sec.pending[k]); sec.pending = {}; } }
    function flag(block, key, on) { const c = Object.assign({}, v); c[block + "|" + key] = on ? "" : null; v = c; NiriConf.flag(block, key, on); }

    Label { text: "Keyboard"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6 }
    // ── The keyboard's languages ──
    // Picked from a grid of every layout the system has (xkb's own list, with its names) instead
    // of typed as codes. niri: input.kdl's xkb block. Hyprland: kb_layout in Monolith's input
    // file (scripts/hypr_input.py), which is read after your own config.
    property var layouts: []            // [code, name], by name
    Process {
        running: true
        command: ["sh", "-c", "for d in \"$XKB_CONFIG_ROOT\" /usr/share/X11/xkb /usr/share/xkeyboard-config-2 /usr/local/share/X11/xkb; do for f in evdev.lst base.lst; do [ -r \"$d/rules/$f\" ] && exec cat \"$d/rules/$f\"; done; done"]
        stdout: StdioCollector { onStreamFinished: sec.layouts = sec.layoutList(text) }
    }
    // the "! layout" part of xkb's list: "  gr              Greek"
    function layoutList(text) {
        const out = [];
        let on = false;
        for (const l of text.split("\n")) {
            if (l.startsWith("!")) { on = l.trim() === "! layout"; continue; }
            const m = on ? l.match(/^\s*(\S+)\s+(.+?)\s*$/) : null;
            if (m && m[1] !== "custom") out.push([m[1], m[2]]);
        }
        out.sort((a, b) => a[1].localeCompare(b[1]));
        return out;
    }
    property string hyprLayout: ""
    property string hyprVariant: ""
    property string hyprOptions: ""
    readonly property string kbLayout: Niri.hyprland ? hyprLayout : NiriConf.unquote(val("input/keyboard/xkb|layout", ""))
    readonly property string kbVariant: Niri.hyprland ? hyprVariant : NiriConf.unquote(val("input/keyboard/xkb|variant", ""))
    readonly property string kbOptions: Niri.hyprland ? hyprOptions : NiriConf.unquote(val("input/keyboard/xkb|options", ""))
    readonly property var kbCodes: kbLayout.split(",").map(c => c.trim()).filter(c => c !== "")
    // the keys that switch language (xkb's grp: option), in words
    readonly property var switchKeys: ({
        "grp:alt_shift_toggle": "Alt + Shift", "grp:lalt_lshift_toggle": "Left Alt + Left Shift", "grp:win_space_toggle": "Super + Space",
        "grp:ctrl_shift_toggle": "Ctrl + Shift", "grp:ctrl_alt_toggle": "Ctrl + Alt", "grp:alt_space_toggle": "Alt + Space",
        "grp:ctrl_space_toggle": "Ctrl + Space", "grp:caps_toggle": "Caps Lock", "grp:shift_caps_toggle": "Shift + Caps Lock",
        "grp:shifts_toggle": "both Shift keys", "grp:alts_toggle": "both Alt keys", "grp:ctrls_toggle": "both Ctrl keys",
        "grp:toggle": "Right Alt", "grp:menu_toggle": "the Menu key", "grp:alt_caps_toggle": "Alt + Caps Lock"
    })
    readonly property string switchKey: { const g = kbOptions.split(",").map(o => o.trim()).find(o => o.startsWith("grp:")); return g ? (switchKeys[g] || g) : ""; }
    function setLayouts(codes) {
        const layout = codes.join(",");
        if (layout === kbCodes.join(",")) return;
        // a layout's variant (us: dvorak) stays with it
        let variant = null;
        if (kbVariant.replace(/,/g, "").trim() !== "") {
            const old = kbVariant.split(",");
            variant = codes.map(c => { const i = kbCodes.indexOf(c); return i >= 0 ? (old[i] || "").trim() : ""; }).join(",");
        }
        // more than one needs keys to switch between them: Alt + Shift, unless some are set already
        let options = null;
        if (codes.length > 1 && switchKey === "") options = (kbOptions.trim() !== "" ? kbOptions.trim() + "," : "") + "grp:alt_shift_toggle";
        if (Niri.hyprland) {
            // (only what changed is written: your own config's variant and options stay yours)
            const w = Object.assign({}, hyprKb, { kb_layout: layout });
            hyprLayout = layout;
            if (variant !== null) { hyprVariant = variant; w.kb_variant = variant; }
            if (options !== null) { hyprOptions = options; w.kb_options = options; }
            hyprKb = w;
            hyprKbWrite.restart();
        } else {
            put("input/keyboard/xkb", "layout", NiriConf.quote(layout));
            if (variant !== null) put("input/keyboard/xkb", "variant", NiriConf.quote(variant));
            if (options !== null) put("input/keyboard/xkb", "options", NiriConf.quote(options));
        }
    }
    property var hyprKb: ({})           // what's waiting to be written on Hyprland: { kb_layout, … }
    Process { id: hyprKbSet }
    // (a moment after the last click: picking three in a row is one change)
    Timer {
        id: hyprKbWrite; interval: 350
        onTriggered: {
            const args = [];
            for (const k in sec.hyprKb) args.push(k, sec.hyprKb[k]);
            sec.hyprKb = {};
            hyprKbSet.command = ["python3", sec.hyprInput, "set"].concat(args);
            hyprKbSet.running = true;
        }
    }
    SettingRow {
        icon: "language"; title: "Keyboard languages"
        desc: "The layouts you type in" + (sec.kbCodes.length > 1 ? (sec.switchKey !== "" ? ". Switch between them with " + sec.switchKey : "") : ": add another to switch between them")
        MultiPicker {
            visible: sec.layouts.length > 0
            opts: sec.layouts
            value: sec.kbCodes
            most: 4     // (as many as a keyboard map holds)
            noun: "languages"
            hint: "Click a language to add or remove it. Number 1 is the one you start in."
            onPicked: codes => sec.setLayouts(codes)
        }
        // (no list of layouts on this system: typed, as codes)
        Field {
            visible: sec.layouts.length === 0
            text: sec.kbLayout; placeholder: "us,de"
            onAccepted: t => { const c = t.split(",").map(x => x.trim()).filter(x => /^[A-Za-z0-9_]+$/.test(x)); if (c.length) sec.setLayouts(c); }
        }
    }
    SettingRow {
        icon: "timer"; title: "Repeat delay"; desc: "How long a key is held before it repeats"
        NumberBox { from: 50; to: 3000; slideTo: 1500; step: 25; unit: "ms"; value: Number(sec.val("input/keyboard|repeat-delay", 600)); onMoved: x => sec.put("input/keyboard", "repeat-delay", x) }
    }
    SettingRow {
        icon: "fast_forward"; title: "Repeat rate"
        NumberBox { from: 1; to: 200; slideTo: 100; unit: "/s"; value: Number(sec.val("input/keyboard|repeat-rate", 25)); onMoved: x => sec.put("input/keyboard", "repeat-rate", x) }
    }
    SettingRow {
        icon: "dialpad"; title: "Num Lock on at login"
        Toggle { checked: sec.has("input/keyboard|numlock"); onToggled: on => sec.flag("input/keyboard", "numlock", on) }
    }

    Label { text: "Mouse"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    SettingRow {
        icon: "mouse"; title: "Mouse speed"; desc: "0 is normal; down to −1 slower, up to 1 faster"
        NumberBox { from: -1; to: 1; step: 0.05; decimals: 2; value: Number(sec.val("input/mouse|accel-speed", 0)); onMoved: x => sec.put("input/mouse", "accel-speed", x.toFixed(2)) }
    }
    SettingRow {
        icon: "trending_flat"; title: "No acceleration"; desc: "The pointer moves exactly as far as the mouse (good for games)"
        Toggle { checked: NiriConf.unquote(sec.val("input/mouse|accel-profile", "")) === "flat"; onToggled: on => sec.put("input/mouse", "accel-profile", on ? "\"flat\"" : "\"adaptive\"") }
    }
    // the mouse wheel's speed: niri's scroll-factor, or on Hyprland input:scroll_factor in
    // Monolith's file (scripts/hypr_input.py). Apps and Monolith's own menus follow it
    // (the compositor makes each notch a bigger or smaller step)
    readonly property string hyprInput: Qt.resolvedUrl("../../scripts/hypr_input.py").toString().replace("file://", "")
    property real hyprScroll: 1
    Process {
        running: Niri.hyprland
        command: ["python3", sec.hyprInput, "read"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    if (Number(d.scroll_factor) > 0) sec.hyprScroll = Number(d.scroll_factor);
                    sec.hyprLayout = d.kb_layout || ""; sec.hyprVariant = d.kb_variant || ""; sec.hyprOptions = d.kb_options || "";
                } catch (e) {}
            }
        }
    }
    Process { id: hyprSet }
    Timer { id: hyprWrite; interval: 350; onTriggered: { hyprSet.command = ["python3", sec.hyprInput, "set", "scroll_factor", sec.hyprScroll.toFixed(2)]; hyprSet.running = true; } }
    SettingRow {
        icon: "unfold_more"; title: "Mouse scroll speed"; desc: "How far one notch of the wheel scrolls, everywhere (apps and Monolith). 1× is normal"
        NumberBox {
            from: 0.1; to: 5; slideTo: 3; step: 0.05; decimals: 2; unit: "×"
            value: Niri.hyprland ? sec.hyprScroll : Number(sec.val("input/mouse|scroll-factor", 1))
            onMoved: x => {
                if (Niri.hyprland) { sec.hyprScroll = x; hyprWrite.restart(); }
                else sec.put("input/mouse", "scroll-factor", x.toFixed(2));
            }
        }
    }
    SettingRow {
        icon: "swap_vert"; title: "Natural scrolling (mouse)"
        Toggle { checked: sec.has("input/mouse|natural-scroll"); onToggled: on => sec.flag("input/mouse", "natural-scroll", on) }
    }

    Label { text: "Touchpad"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    SettingRow {
        icon: "touch_app"; title: "Tap to click"
        Toggle { checked: sec.has("input/touchpad|tap"); onToggled: on => sec.flag("input/touchpad", "tap", on) }
    }
    SettingRow {
        icon: "swap_vert"; title: "Natural scrolling (touchpad)"
        Toggle { checked: sec.has("input/touchpad|natural-scroll"); onToggled: on => sec.flag("input/touchpad", "natural-scroll", on) }
    }
    SettingRow {
        icon: "keyboard_hide"; title: "Off while typing"
        Toggle { checked: sec.has("input/touchpad|dwt"); onToggled: on => sec.flag("input/touchpad", "dwt", on) }
    }
    SettingRow {
        icon: "speed"; title: "Touchpad speed"
        NumberBox { from: -1; to: 1; step: 0.05; decimals: 2; value: Number(sec.val("input/touchpad|accel-speed", 0)); onMoved: x => sec.put("input/touchpad", "accel-speed", x.toFixed(2)) }
    }
}
