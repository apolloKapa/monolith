import QtQuick
import "../../core"
import "../../ui"

// CPU, memory, temperature, disk or battery, Cyberpunk: its name on the label block, the number
// big with its split signal, and the value as a row of segments.
FaceBase {
    id: f
    readonly property string kind: f.ctx ? f.ctx.type : "cpu"
    Metric { id: m; type: f.kind === "battery" ? "cpu" : f.kind }
    Battery { id: bat }
    readonly property real value: f.kind === "battery" ? bat.level : m.value
    readonly property string number: f.kind === "temp" ? String(Math.round(Stats.temp)) + "°" : String(Math.round(value * 100)) + "%"
    CyberCard {
        id: c; ctx: f.ctx
        label: f.kind === "battery" ? (bat.charging ? "Power // charging" : "Power") : ({ cpu: "CPU", ram: "Memory", temp: "Thermal", disk: "Storage" })[f.kind] || ""
        CyberText { card: c; width: parent.width; height: parent.height * 0.62; align: Text.AlignHCenter; text: f.number; color: f.value > 0.85 ? c.hot : c.ink }
        CyberBar { anchors.bottom: parent.bottom; card: c; width: parent.width; height: Math.max(4, c.u * 0.06); count: 12; value: f.value }
    }
}
