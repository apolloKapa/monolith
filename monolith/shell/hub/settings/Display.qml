import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Displays: on/off, resolution, refresh rate and scale for each monitor. Written into niri's
// output config (niri applies it straight away and keeps it).
ColumnLayout {
    id: sec
    spacing: 8
    property var outputs: []

    Process {
        id: query
        running: true
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector {
            onStreamFinished: {
                try {
                    const d = JSON.parse(text);
                    sec.outputs = Object.keys(d).sort().map(k => d[k]);
                } catch (e) {}
            }
        }
    }
    Timer { id: requery; interval: 1200; onTriggered: query.running = true }
    Connections { target: NiriConf; function onChanged() { requery.restart(); } }

    function block(o) { return "output " + NiriConf.quote(o.name); }
    function modeStr(m) { return m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3); }
    function onCount() { return outputs.filter(o => o.current_mode !== null).length; }

    Label { visible: sec.outputs.length === 0; text: "Looking for displays…"; muted: true }

    Repeater {
        model: sec.outputs
        Rectangle {
            id: card
            required property var modelData
            readonly property var o: modelData
            readonly property bool on: o.current_mode !== null
            readonly property var cur: on ? o.modes[o.current_mode] : null
            // the resolutions (largest first) and the rates at the current one
            readonly property var sizes: {
                const seen = {}, out = [];
                for (const m of o.modes) { const k = m.width + "x" + m.height; if (!seen[k]) { seen[k] = 1; out.push(k); } }
                return out.sort((a, b) => Number(b.split("x")[0]) * Number(b.split("x")[1]) - Number(a.split("x")[0]) * Number(a.split("x")[1])).slice(0, 6);
            }
            readonly property var rates: cur ? o.modes.filter(m => m.width === cur.width && m.height === cur.height).sort((a, b) => b.refresh_rate - a.refresh_rate).slice(0, 4) : []
            Layout.fillWidth: true
            implicitHeight: col.implicitHeight + 24
            radius: Theme.corner(80, 8)
            color: Theme.container

            ColumnLayout {
                id: col
                x: 12; y: 12
                width: parent.width - 24
                spacing: 8
                SettingRow {
                    icon: "monitor"; title: card.o.name + "  ·  " + (card.o.make + " " + card.o.model).trim()
                    desc: card.on ? card.cur.width + " × " + card.cur.height + " at " + Math.round(card.cur.refresh_rate / 1000) + " Hz, scale " + (card.o.logical ? card.o.logical.scale : 1) : "Off"
                    Toggle {
                        checked: card.on
                        // never the last screen that's on
                        onToggled: on => { if (on || sec.onCount() > 1) NiriConf.flag(sec.block(card.o), "off", !on); }
                    }
                }
                SettingRow {
                    visible: card.on
                    icon: "aspect_ratio"; title: "Resolution"
                    Segmented {
                        width: Math.min(420, 110 * card.sizes.length)
                        opts: card.sizes.map(s => [s, s.replace("x", "×")])
                        value: card.cur ? card.cur.width + "x" + card.cur.height : ""
                        onPicked: v => {
                            const best = card.o.modes.filter(m => m.width + "x" + m.height === v).sort((a, b) => b.refresh_rate - a.refresh_rate)[0];
                            if (best) NiriConf.set(sec.block(card.o), "mode", NiriConf.quote(sec.modeStr(best)));
                        }
                    }
                }
                SettingRow {
                    visible: card.on && card.rates.length > 1
                    icon: "speed"; title: "Refresh rate"
                    Segmented {
                        width: Math.min(360, 90 * card.rates.length)
                        opts: card.rates.map(m => [String(m.refresh_rate), Math.round(m.refresh_rate / 1000) + " Hz"])
                        value: card.cur ? String(card.cur.refresh_rate) : ""
                        onPicked: v => {
                            const m = card.rates.find(r => String(r.refresh_rate) === v);
                            if (m) NiriConf.set(sec.block(card.o), "mode", NiriConf.quote(sec.modeStr(m)));
                        }
                    }
                }
                SettingRow {
                    visible: card.on
                    icon: "zoom_in"; title: "Scale"; desc: "Bigger text and controls on this screen"
                    Segmented {
                        width: 300
                        opts: [["1", "100%"], ["1.25", "125%"], ["1.5", "150%"], ["2", "200%"]]
                        value: card.o.logical ? String(card.o.logical.scale) : "1"
                        onPicked: v => NiriConf.set(sec.block(card.o), "scale", v)
                    }
                }
            }
        }
    }
    SettingRow {
        icon: "drag_pan"; title: "Arrangement"; desc: "Where the screens sit next to each other is kept in niri's config/output.kdl (position x= y=)"
    }
}
