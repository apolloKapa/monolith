import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// The status line: where it sits, auto-hide, and which parts show.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "vertical_align_top"; title: "Position"
        Segmented { opts: [["top", "Top"], ["bottom", "Bottom"]]; value: Store.get("status.position", "top"); onPicked: v => Store.set("status.position", v) }
    }
    SettingRow {
        icon: "visibility_off"; title: "Auto-hide"; desc: "Slides away; touch the screen edge to bring it back (Super+A switches this)"
        Toggle { checked: Store.get("status.autohide", false) === true; onToggled: on => Store.set("status.autohide", on) }
    }
    Repeater {
        model: [
            ["weather", "Weather", "partly_cloudy_day", "Beside the clock"],
            ["title", "Window title", "title", "In the middle (the island still shows recordings and the timer)"],
            ["media", "Now playing", "music_note", ""],
            ["stats", "System stats", "memory", "CPU, memory and temperature"],
            ["tray", "Tray", "apps", "Icons of apps running in the background"],
            ["updates", "Updates", "upgrade", "Show when the shell has an update"]
        ]
        SettingRow {
            required property var modelData
            icon: modelData[2]; title: modelData[1]; desc: modelData[3]
            Toggle { checked: Store.get("status.show." + modelData[0], true) !== false; onToggled: on => Store.set("status.show." + modelData[0], on) }
        }
    }
}
