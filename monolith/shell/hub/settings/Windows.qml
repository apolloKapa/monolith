import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Windows: niri's gaps, borders, focus ring, rounded corners and animation speed (written to
// niri's config; niri applies them at once).
ColumnLayout {
    id: sec
    spacing: 8
    property var v: ({})
    function reload() {
        NiriConf.read(["layout|gaps", "layout/border|on", "layout/border|off", "layout/border|width", "layout/focus-ring|off", "layout/focus-ring|on",
                       "window-rule|geometry-corner-radius", "animations|slowdown", "animations|off"], r => sec.v = r);
    }
    Component.onCompleted: reload()
    function has(k) { return v[k] !== null && v[k] !== undefined; }
    function num(k, d) { const x = parseFloat(v[k]); return isNaN(x) ? d : x; }
    // sliders write once, a moment after the last move
    property var pending: ({})
    function put(block, key, value) {
        const c = Object.assign({}, v); c[block + "|" + key] = String(value); v = c;
        const p = Object.assign({}, pending); p[block + "|" + key] = [block, key, value]; pending = p;
        flush.restart();
    }
    Timer { id: flush; interval: 350; onTriggered: { for (const k in sec.pending) NiriConf.set(...sec.pending[k]); sec.pending = {}; } }
    // a block that is on or off: an "on" or "off" line in it
    function onOff(block, on) {
        const c = Object.assign({}, v); c[block + "|on"] = on ? "" : null; c[block + "|off"] = on ? null : ""; v = c;
        NiriConf.flag(block, "off", !on);
        NiriConf.flag(block, "on", on);
    }

    SettingRow {
        icon: "padding"; title: "Gaps"; desc: "Space between windows and around them"
        Slider { width: 240; implicitHeight: 36; icon: "padding"; value: sec.num("layout|gaps", 16) / 40; label: Math.round(sec.num("layout|gaps", 16)) + " px"; onMoved: x => sec.put("layout", "gaps", Math.round(x * 40)) }
    }
    SettingRow {
        icon: "border_outer"; title: "Borders"; desc: "A line around each window, brighter on the focused one"
        Toggle { checked: sec.has("layout/border|on") || (!sec.has("layout/border|off") && sec.has("layout/border|width")); onToggled: on => sec.onOff("layout/border", on) }
    }
    SettingRow {
        icon: "line_weight"; title: "Border width"
        Slider { width: 240; implicitHeight: 36; icon: "line_weight"; value: (sec.num("layout/border|width", 2) - 1) / 7; label: Math.round(sec.num("layout/border|width", 2)) + " px"; onMoved: x => sec.put("layout/border", "width", Math.round(1 + x * 7)) }
    }
    SettingRow {
        icon: "center_focus_strong"; title: "Focus ring"; desc: "A ring outside the focused window (on top of the border)"
        Toggle { checked: sec.has("layout/focus-ring|on"); onToggled: on => sec.onOff("layout/focus-ring", on) }
    }
    SettingRow {
        icon: "rounded_corner"; title: "Window corners"; desc: "How round the windows are"
        Slider {
            width: 240; implicitHeight: 36; icon: "rounded_corner"
            value: sec.num("window-rule|geometry-corner-radius", 0) / 24
            label: Math.round(sec.num("window-rule|geometry-corner-radius", 0)) + " px"
            // (windows are cut to the rounded shape too: clip-to-geometry)
            onMoved: x => { sec.put("window-rule", "geometry-corner-radius", Math.round(x * 24)); sec.put("window-rule", "clip-to-geometry", "true"); }
        }
    }
    SettingRow {
        icon: "animation"; title: "Animations"
        Toggle { checked: !sec.has("animations|off"); onToggled: on => { const c = Object.assign({}, sec.v); c["animations|off"] = on ? null : ""; sec.v = c; NiriConf.flag("animations", "off", !on); } }
    }
    SettingRow {
        icon: "speed"; title: "Animation speed"; desc: "niri's slowdown: lower is faster"
        Slider { width: 240; implicitHeight: 36; icon: "speed"; value: (sec.num("animations|slowdown", 1) - 0.2) / 1.8; label: sec.num("animations|slowdown", 1).toFixed(2) + "×"; onMoved: x => sec.put("animations", "slowdown", (0.2 + x * 1.8).toFixed(2)) }
    }
}
