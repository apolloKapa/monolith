import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// The island's bar: auto-hide, and which parts show.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "visibility_off"; title: "Auto-hide"; desc: "The island slides up; touch the top edge to bring it back (Super+A switches this)"
        Toggle { checked: Store.get("status.autohide", false) === true; onToggled: on => Store.set("status.autohide", on) }
    }
    Repeater {
        model: [
            ["weather", "Weather", "partly_cloudy_day", "Beside the clock"],
            ["title", "Window title", "title", "In the middle when nothing is playing"],
            ["media", "Now playing", "music_note", "In the middle, with the album art"],
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
