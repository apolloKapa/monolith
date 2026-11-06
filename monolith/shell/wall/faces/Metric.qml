import QtQuick
import "../../core"
import "../../ui"

// CPU, memory, temperature or disk, for the usage looks: value 0..1, the big text, the name, a
// detail line and the icon and colour.
QtObject {
    property string type: "cpu"
    readonly property real value: type === "cpu" ? Stats.cpu : type === "ram" ? Stats.mem : type === "temp" ? Math.min(1, Stats.temp / 100) : Stats.disk
    readonly property string text: type === "cpu" ? Math.round(Stats.cpu * 100) + "%"
        : type === "ram" ? (Stats.memUsed / 1073741824).toFixed(1) + "G"
        : type === "temp" ? Math.round(Stats.temp) + "°" : Math.round(Stats.disk * 100) + "%"
    readonly property string title: ({ cpu: "CPU", ram: "Memory", temp: "Temperature", disk: "Disk" })[type] || ""
    readonly property string detail: type === "ram" ? Math.round(Stats.mem * 100) + "% of " + Stats.bytes(Stats.memTotal)
        : type === "disk" ? Stats.bytes(Stats.diskUsed) + " of " + Stats.bytes(Stats.diskTotal)
        : type === "temp" ? (Stats.gpuTemp > 0 ? "GPU " + Math.round(Stats.gpuTemp) + "°" : "")
        : (Stats.cpuHist.length ? "avg " + Math.round(Stats.cpuHist.reduce((a, b) => a + b, 0) / Stats.cpuHist.length * 100) + "%" : "")
    readonly property string icon: ({ cpu: "developer_board", ram: "memory_alt", temp: "device_thermostat", disk: "hard_drive" })[type] || "monitoring"
    readonly property color color: type === "cpu" ? Qt.lighter(Theme.accent, 1.3) : type === "ram" ? Qt.lighter(Theme.accent, 1.1)
        : type === "temp" ? Theme.m("tertiary", Theme.accent) : Theme.m("secondary", Theme.accent)
}
