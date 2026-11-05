import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Where menus open: out of the island at the top, in the middle of the screen, or on the right.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "open_in_new"; title: "Where menus open"; desc: "The launcher, control center, settings and every other menu"
        Segmented {
            width: 330
            opts: [["top", "Top (island)"], ["center", "Middle"], ["right", "Right"]]
            value: Store.get("menus.position", "top")
            onPicked: v => Store.set("menus.position", v)
        }
    }
    SettingRow {
        icon: "info"; title: "Top"; desc: "The island grows down into the menu, the bar staying on top of it"
    }
    SettingRow {
        icon: "info"; title: "Middle and right"; desc: "The menu floats as a card there; the island stays a bar"
    }
}
