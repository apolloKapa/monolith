import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Keyboard (layouts, repeat), mouse and touchpad: niri's input config.
ColumnLayout {
    id: sec
    spacing: 8
    property var v: ({})
    function val(spec, fallback) { const x = v[spec]; return x === null || x === undefined ? fallback : x; }
    function has(spec) { return v[spec] !== null && v[spec] !== undefined; }
    function reload() {
        NiriConf.read(["input/keyboard/xkb|layout", "input/keyboard/xkb|options", "input/keyboard|repeat-delay", "input/keyboard|repeat-rate", "input/keyboard|numlock",
                       "input/mouse|accel-speed", "input/mouse|accel-profile", "input/mouse|natural-scroll",
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
    SettingRow {
        icon: "language"; title: "Layouts"; desc: "Comma-separated, like us,de. Switch with " + (NiriConf.unquote(sec.val("input/keyboard/xkb|options", "")) || "your layout keybind")
        Field { text: NiriConf.unquote(sec.val("input/keyboard/xkb|layout", "")); placeholder: "us"; onAccepted: t => { if (t.trim() !== "" && t.trim() !== NiriConf.unquote(sec.val("input/keyboard/xkb|layout", ""))) sec.put("input/keyboard/xkb", "layout", NiriConf.quote(t.trim())); } }
    }
    SettingRow {
        icon: "timer"; title: "Repeat delay"; desc: "How long a key is held before it repeats"
        NumberBox { from: 50; to: 3000; step: 25; unit: "ms"; value: Number(sec.val("input/keyboard|repeat-delay", 600)); onMoved: x => sec.put("input/keyboard", "repeat-delay", x) }
    }
    SettingRow {
        icon: "fast_forward"; title: "Repeat rate"
        NumberBox { from: 1; to: 200; unit: "/s"; value: Number(sec.val("input/keyboard|repeat-rate", 25)); onMoved: x => sec.put("input/keyboard", "repeat-rate", x) }
    }
    SettingRow {
        icon: "dialpad"; title: "Num Lock on at login"
        Toggle { checked: sec.has("input/keyboard|numlock"); onToggled: on => sec.flag("input/keyboard", "numlock", on) }
    }

    Label { text: "Mouse"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    SettingRow {
        icon: "mouse"; title: "Speed"
        NumberBox { from: -1; to: 1; step: 0.05; decimals: 2; value: Number(sec.val("input/mouse|accel-speed", 0)); onMoved: x => sec.put("input/mouse", "accel-speed", x.toFixed(2)) }
    }
    SettingRow {
        icon: "trending_flat"; title: "No acceleration"; desc: "The pointer moves exactly as far as the mouse (good for games)"
        Toggle { checked: NiriConf.unquote(sec.val("input/mouse|accel-profile", "")) === "flat"; onToggled: on => sec.put("input/mouse", "accel-profile", on ? "\"flat\"" : "\"adaptive\"") }
    }
    SettingRow {
        icon: "swap_vert"; title: "Natural scrolling"
        Toggle { checked: sec.has("input/mouse|natural-scroll"); onToggled: on => sec.flag("input/mouse", "natural-scroll", on) }
    }

    Label { text: "Touchpad"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    SettingRow {
        icon: "touch_app"; title: "Tap to click"
        Toggle { checked: sec.has("input/touchpad|tap"); onToggled: on => sec.flag("input/touchpad", "tap", on) }
    }
    SettingRow {
        icon: "swap_vert"; title: "Natural scrolling"
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
