import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// System monitor: what a click on the bar's stats opens, and the warnings when the video memory,
// memory or a temperature goes too high (a notification after ten seconds over the line; again
// only once it has been fine for a minute).
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var w: Stats.warn
    function put(k, v) { const o = Object.assign({}, Store.get("sysmon.warn", ({})) || ({})); o[k] = v; Store.set("sysmon.warn", o); }

    SettingRow {
        key: "sysmon.dropdown"; def: true;
        icon: "monitoring"; title: "Clicking the bar's stats"; desc: Store.get("sysmon.dropdown", true) !== false ? "Drops down live graphs and the busiest apps (end one from there)" : "Opens the control center's Monitor"
        Segmented { width: 260; opts: [["drop", "Dropdown"], ["cc", "Control center"]]; value: Store.get("sysmon.dropdown", true) !== false ? "drop" : "cc"; onPicked: v => Store.set("sysmon.dropdown", v === "drop") }
    }
    SettingRow {
        icon: "toolbar"; title: "What the bar shows"; desc: "CPU, memory, temperatures, GPU and video memory: Bar → Layout & modules → System stats"
        Button { text: "Open"; onClicked: HubState.settingsSection = "bar" }
    }
    SectionHead { text: "Warnings" }
    SettingRow {
        keys: ["sysmon.warn"];
        icon: "warning"; title: "Warn me"; desc: "A notification (it shows even over games) when one of these stays over its line for ten seconds"
        Toggle { checked: Stats.warnOn; onToggled: on => sec.put("on", on) }
    }
    SettingRow {
        visible: Stats.warnOn && Stats.vramTotal > 0
        icon: "developer_board"; title: "Video memory over"; desc: "Now " + Math.round(Stats.vram * 100) + "% of " + Stats.bytes(Stats.vramTotal) + ". A full GPU memory makes games stutter or the GPU stall"
        NumberBox { from: 50; to: 100; unit: "%"; value: Number(sec.w.vram || 95); onMoved: v => sec.put("vram", v) }
    }
    SettingRow {
        visible: Stats.warnOn
        icon: "data_usage"; title: "Memory over"; desc: "Now " + Math.round(Stats.mem * 100) + "%"
        NumberBox { from: 50; to: 100; unit: "%"; value: Number(sec.w.mem || 95); onMoved: v => sec.put("mem", v) }
    }
    SettingRow {
        visible: Stats.warnOn && Stats.tempPath !== ""
        icon: "thermostat"; title: "CPU hotter than"; desc: "Now " + Math.round(Stats.temp) + " °C"
        NumberBox { from: 60; to: 110; unit: " °C"; value: Number(sec.w.cpuTemp || 90); onMoved: v => sec.put("cpuTemp", v) }
    }
    SettingRow {
        visible: Stats.warnOn && Stats.gpuTempPath !== ""
        icon: "device_thermostat"; title: "GPU hotter than"; desc: "Now " + Math.round(Stats.gpuTemp) + " °C (its edge sensor; the hotspot runs higher)"
        NumberBox { from: 60; to: 110; unit: " °C"; value: Number(sec.w.gpuTemp || 95); onMoved: v => sec.put("gpuTemp", v) }
    }
}
