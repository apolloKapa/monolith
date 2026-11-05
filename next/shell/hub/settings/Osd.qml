import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "featured_video"; title: "On-screen display"; desc: "A small pill when the volume or keyboard layout changes"
        Toggle { checked: Store.get("osd.enabled", true) !== false; onToggled: on => Store.set("osd.enabled", on) }
    }
    SettingRow {
        icon: "vertical_split"; title: "Position"
        Segmented { opts: [["top", "Top"], ["bottom", "Bottom"]]; value: Store.get("osd.position", "bottom"); onPicked: v => Store.set("osd.position", v) }
    }
    SettingRow {
        icon: "volume_up"; title: "Volume"
        Toggle { checked: Store.get("osd.show.volume", true) !== false; onToggled: on => Store.set("osd.show.volume", on) }
    }
    SettingRow {
        icon: "keyboard"; title: "Keyboard layout"
        Toggle { checked: Store.get("osd.show.layout", true) !== false; onToggled: on => Store.set("osd.show.layout", on) }
    }
}
