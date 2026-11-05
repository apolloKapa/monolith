import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Night light: warmer colours, always or on a schedule.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "nightlight"; title: "Night light"; desc: "Warmer, less blue light. Also a tile in the control center"
        Toggle { checked: NightLight.enabled; onToggled: on => Store.set("nightlight.enabled", on) }
    }
    SettingRow {
        icon: "thermostat"; title: "Warmth"; desc: "Lower is warmer"
        NumberBox { from: 1000; to: 6500; step: 100; unit: "K"; value: NightLight.temp; onMoved: v => Store.set("nightlight.temp", v) }
    }
    SettingRow {
        icon: "schedule"; title: "When"
        desc: NightLight.schedule === "sun" && !Weather.loc ? "Sunset to sunrise needs your location (General)" : ""
        Segmented {
            width: 330
            opts: [["always", "Always"], ["sun", "Sunset to sunrise"], ["custom", "Set times"]]
            value: NightLight.schedule
            onPicked: v => Store.set("nightlight.schedule", v)
        }
    }
    SettingRow {
        visible: NightLight.schedule === "custom"
        icon: "more_time"; title: "From and to"; desc: "24-hour times, like 21:00 and 07:00"
        Row {
            spacing: 6
            Field { width: 100; text: NightLight.from; onAccepted: v => { if (/^\d{1,2}:\d{2}$/.test(v.trim())) Store.set("nightlight.from", v.trim().padStart(5, "0")); } }
            Field { width: 100; text: NightLight.to; onAccepted: v => { if (/^\d{1,2}:\d{2}$/.test(v.trim())) Store.set("nightlight.to", v.trim().padStart(5, "0")); } }
        }
    }
}
