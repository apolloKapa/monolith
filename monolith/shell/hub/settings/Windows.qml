import QtQuick
import QtQuick.Layouts
import Quickshell.Io
import "../../core"
import "../../ui"

// Windows: niri's gaps, borders, focus ring and rounded corners (written to
// niri's config; niri applies them at once).
ColumnLayout {
    id: sec
    spacing: 8
    property var v: ({})
    function reload() {
        NiriConf.read(["layout|gaps", "layout/border|on", "layout/border|off", "layout/border|width", "layout/focus-ring|off", "layout/focus-ring|on",
                       "layout/border|active-color", "layout/border|active-gradient", "layout/border|inactive-color", "layout/border|inactive-gradient",
                       "window-rule|geometry-corner-radius", "recent-windows|off", "recent-windows|open-delay-ms", "recent-windows/previews|max-height"], r => sec.v = r);
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

    // ── border colours (niri, or Hyprland through Monolith's own file: scripts/hypr_borders.py) ──
    // a side: { a: colour, b: "" (one colour) or the colour it fades to, angle }
    function gradParts(g) {
        const f = /from="([^"]+)"/.exec(g || ""), t = /to="([^"]+)"/.exec(g || ""), an = /angle=(-?[0-9.]+)/.exec(g || "");
        return f && t ? { a: f[1], b: t[1], angle: an ? Number(an[1]) : 180 } : null;
    }
    function niriSide(side, dflt) {
        const g = gradParts(v["layout/border|" + side + "-gradient"]);
        return g || { a: NiriConf.unquote(v["layout/border|" + side + "-color"]) || dflt, b: "", angle: 180 };
    }
    property var hyprB: ({})
    readonly property string hyprScript: Qt.resolvedUrl("../../scripts/hypr_borders.py").toString().replace("file://", "")
    Process {
        running: Niri.hyprland
        command: ["python3", sec.hyprScript, "read"]
        stdout: StdioCollector { onStreamFinished: { try { sec.hyprB = JSON.parse(text); } catch (e) {} } }
    }
    readonly property var activeB: Niri.hyprland ? (hyprB.active || { a: "#ffffff", b: "", angle: 45 }) : niriSide("active", "#ffffff")
    readonly property var inactiveB: Niri.hyprland ? (hyprB.inactive || { a: "#444444", b: "", angle: 45 }) : niriSide("inactive", "#505050")
    function setSide(side, val) {
        if (Niri.hyprland) {
            const c = Object.assign({ width: 2 }, hyprB); c[side] = val; hyprB = c;
            hyprSave.restart();
            return;
        }
        const k = Object.assign({}, v);
        if (val.b) {
            const g = 'from="' + val.a + '" to="' + val.b + '" angle=' + Math.round(val.angle);
            k["layout/border|" + side + "-gradient"] = g;
            NiriConf.set("layout/border", side + "-gradient", g);
        } else {
            k["layout/border|" + side + "-gradient"] = null;
            NiriConf.unset("layout/border", side + "-gradient");
        }
        k["layout/border|" + side + "-color"] = NiriConf.quote(val.a);
        NiriConf.set("layout/border", side + "-color", NiriConf.quote(val.a));
        v = k;
    }
    Process { id: hyprWriter }
    Timer {
        id: hyprSave; interval: 400
        onTriggered: { hyprWriter.command = ["python3", sec.hyprScript, "apply", JSON.stringify(sec.hyprB)]; hyprWriter.running = true; }
    }
    // one side's rows: one colour or a fade, its colour(s), and the fade's angle
    component BorderSide: ColumnLayout {
        id: bs
        property string side: "active"
        property string title: ""
        property var val: ({ a: "#ffffff", b: "", angle: 45 })
        Layout.fillWidth: true
        spacing: 8
        function put(ch) { sec.setSide(bs.side, Object.assign({}, bs.val, ch)); }
        SettingRow {
            Layout.fillWidth: true
            icon: bs.side === "active" ? "select_window" : "tab_unselected"; title: bs.title
            desc: bs.val.b ? "Fades from one colour to the other" : "One colour"
            Row {
                spacing: 10
                Segmented { width: 170; opts: [["solid", "Solid"], ["fade", "Fade"]]; value: bs.val.b ? "fade" : "solid"
                    onPicked: x => bs.put({ b: x === "fade" ? (bs.val.b || String(Theme.accent).substring(0, 7)) : "" }) }
                ColourPick { value: bs.val.a; onPicked: c => bs.put({ a: c }) }
            }
        }
        SettingRow {
            Layout.fillWidth: true
            visible: !!bs.val.b
            icon: "gradient"; title: "Fades to"; desc: "And the direction it fades in"
            Row {
                spacing: 10
                ColourPick { value: bs.val.b || "#000000"; onPicked: c => bs.put({ b: c }) }
                NumberBox { width: 190; from: 0; to: 359; unit: "°"; value: bs.val.angle; onMoved: x => bs.put({ angle: x }) }
            }
        }
    }

    SettingRow {
        visible: Niri.hyprland
        icon: "line_weight"; title: "Border width"; desc: "0: no border"
        NumberBox { from: 0; to: 20; unit: "px"; value: sec.hyprB.width !== undefined ? sec.hyprB.width : 2
            onMoved: x => { const c = Object.assign({}, sec.hyprB); c.width = Math.round(x); sec.hyprB = c; hyprSave.restart(); } }
    }

    SettingRow {
        visible: !Niri.hyprland
        icon: "padding"; title: "Gaps"; desc: "Space between windows and around them"
        NumberBox { from: 0; to: 200; slideTo: 60; unit: "px"; value: sec.num("layout|gaps", 16); onMoved: x => sec.put("layout", "gaps", x) }
    }
    SettingRow {
        visible: !Niri.hyprland
        icon: "border_outer"; title: "Borders"; desc: "A line around each window, brighter on the focused one"
        Toggle { checked: sec.has("layout/border|on") || (!sec.has("layout/border|off") && sec.has("layout/border|width")); onToggled: on => sec.onOff("layout/border", on) }
    }
    SettingRow {
        visible: !Niri.hyprland
        icon: "line_weight"; title: "Border width"
        NumberBox { from: 1; to: 50; slideTo: 12; unit: "px"; value: sec.num("layout/border|width", 2); onMoved: x => sec.put("layout/border", "width", x) }
    }
    BorderSide { side: "active"; title: "Focused window's border"; val: sec.activeB }
    BorderSide { side: "inactive"; title: "Other windows' border"; val: sec.inactiveB }
    SettingRow {
        visible: !Niri.hyprland
        icon: "center_focus_strong"; title: "Focus ring"; desc: "A ring outside the focused window (on top of the border)"
        Toggle { checked: sec.has("layout/focus-ring|on"); onToggled: on => sec.onOff("layout/focus-ring", on) }
    }
    SettingRow {
        visible: !Niri.hyprland
        icon: "rounded_corner"; title: "Window corners"; desc: "How round the windows are"
        // (windows are cut to the rounded shape too: clip-to-geometry)
        NumberBox { from: 0; to: 100; slideTo: 40; unit: "px"; value: sec.num("window-rule|geometry-corner-radius", 0); onMoved: x => { sec.put("window-rule", "geometry-corner-radius", x); sec.put("window-rule", "clip-to-geometry", "true"); } }
    }
    // (window animations and their speeds: Appearance → Animation speeds)
    SettingRow {
        icon: "animation"; title: "Window animations"; desc: "How fast windows, workspaces and the overview move: in Animations → Speeds & windows"
        Button { text: "Open"; icon: "arrow_forward"; onClicked: HubState.openSettings("animations") }
    }

    // ── Alt+Tab: niri's window switcher (live previews), in the shell's look (core/AltTab) ──
    SectionHead { text: "Alt+Tab"; visible: !Niri.hyprland }
    SettingRow {
        visible: !Niri.hyprland
        icon: "tab"; title: "Window switcher"; desc: "Alt+Tab (Alt+Shift+Tab back) shows your windows, most recent first, with live previews; let go of Alt to switch"
        Toggle { checked: !sec.has("recent-windows|off"); onToggled: on => { const c = Object.assign({}, sec.v); c["recent-windows|off"] = on ? null : ""; sec.v = c; NiriConf.flag("recent-windows", "off", !on); } }
    }
    SettingRow {
        visible: !Niri.hyprland && !sec.has("recent-windows|off")
        key: "alttab.theme"; def: true
        icon: "palette"; title: "In the theme's look"; desc: "The chosen window is outlined in your accent colour, with your corners; it follows the wallpaper and theme"
        Toggle { checked: Store.get("alttab.theme", true) !== false; onToggled: on => Store.set("alttab.theme", on) }
    }
    SettingRow {
        visible: !Niri.hyprland && !sec.has("recent-windows|off")
        icon: "photo_size_select_large"; title: "Preview size"; desc: "How big each window's preview is"
        Segmented {
            width: 300
            opts: [["320", "Small"], ["480", "Medium"], ["640", "Large"]]
            value: { const h = sec.num("recent-windows/previews|max-height", 480); return h <= 400 ? "320" : (h <= 560 ? "480" : "640"); }
            onPicked: h => sec.put("recent-windows/previews", "max-height", h)
        }
    }
    SettingRow {
        visible: !Niri.hyprland && !sec.has("recent-windows|off")
        icon: "timer"; title: "Show after"; desc: "A quick Alt+Tab just switches to the last window; held this long, the switcher shows"
        NumberBox { from: 0; to: 1000; slideTo: 600; step: 10; unit: "ms"; value: sec.num("recent-windows|open-delay-ms", 150); onMoved: x => sec.put("recent-windows", "open-delay-ms", Math.round(x)) }
    }
}
