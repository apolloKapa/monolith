import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Where menus open: a default, and each menu on its own if you like (a drop-down per menu).
ColumnLayout {
    id: sec
    spacing: 8
    readonly property var places: [["top", "Top (out of the bar)", "The bar grows down into the menu"],
                                   ["center", "Middle of the screen", "A card floating in the middle"],
                                   ["right", "Right side", "A card along the right edge"]]
    // each menu can follow the default or have its own place
    readonly property var withDefault: [["", "Same as the default", ""]].concat(places)
    readonly property var menus: [
        ["search", "Launcher (Search)", "search"], ["quick", "Control center", "page_info"], ["notifications", "Notifications", "notifications"],
        ["media", "Media", "music_note"], ["calendar", "Calendar & weather", "calendar_month"], ["sound", "Sound", "volume_up"],
        ["network", "Network", "wifi"], ["clipboard", "Clipboard", "content_paste"], ["windows", "Windows", "select_window"],
        ["capture", "Capture", "screenshot_region"], ["gaming", "Gaming", "sports_esports"], ["tools", "Tools", "construction"],
        ["wellbeing", "Wellbeing", "self_improvement"], ["keys", "Keybinds", "keyboard_command_key"], ["settings", "Settings", "settings"]
    ]

    SettingRow {
        icon: "open_in_new"; title: "Menus open at"; desc: "Where every menu appears, unless you give it its own place below"
        Dropdown { width: 260; opts: sec.places; value: Store.get("menus.position", "top"); onPicked: v => Store.set("menus.position", v) }
    }
    Label { text: "Each menu"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    Repeater {
        model: sec.menus
        SettingRow {
            required property var modelData
            readonly property string own: Store.get("menus.positions." + modelData[0], "")
            icon: modelData[2]; title: modelData[1]
            desc: own === "" ? "Follows the default" : ""
            Dropdown {
                width: 260
                opts: sec.withDefault
                value: parent.parent.own
                onPicked: v => Store.set("menus.positions." + modelData[0], v)
            }
        }
    }
}
