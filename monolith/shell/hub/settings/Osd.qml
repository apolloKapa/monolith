import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "featured_video"; title: "Show a pop-up"; desc: "A small pill when you change the volume, keyboard layout, Caps Lock or Num Lock"
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
    Repeater {
        model: [["layout", "Keyboard layout", "keyboard"], ["caps", "Caps Lock", "keyboard_capslock"], ["num", "Num Lock", "pin"], ["airplane", "Airplane mode", "airplanemode_active"]]
        SettingRow {
            required property var modelData
            icon: modelData[2]; title: modelData[1]
            Toggle { checked: Store.get("osd.show." + modelData[0], true) !== false; onToggled: on => Store.set("osd.show." + modelData[0], on) }
        }
    }
}
