import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "drag_pan"; title: "Move widgets"; desc: "Drag the widgets on your desktop where you want them, then turn this off"
        Toggle { checked: Store.get("widgets.editing", false); onToggled: on => Store.set("widgets.editing", on) }
    }
    Repeater {
        model: [
            ["clock", "Clock", "schedule", "", true],
            ["weather", "Weather", "partly_cloudy_day", "", true],
            ["media", "Now playing", "music_note", "Shows while something plays", true],
            ["calendar", "Calendar", "calendar_month", "This month", false],
            ["usage", "System usage", "memory", "CPU, memory and temperature", false],
            ["notes", "Notes", "sticky_note_2", "The same notes as in Tools", false],
            ["image", "Picture", "image", "A picture of yours", false]
        ]
        SettingRow {
            required property var modelData
            icon: modelData[2]; title: modelData[1]; desc: modelData[3]
            Toggle { checked: Store.get("widgets.hidden." + modelData[0], !modelData[4]) !== true; onToggled: on => Store.set("widgets.hidden." + modelData[0], !on) }
        }
    }
    SettingRow {
        icon: "image"; title: "Picture"; desc: "The file the picture widget shows"
        Field { text: Store.get("widgets.imagePath", ""); placeholder: "/path/to/picture.png"; onAccepted: v => { const p = v.trim().replace(/^~/, Wall.home); if (p !== Store.get("widgets.imagePath", "")) Store.set("widgets.imagePath", p); } }
    }
}
