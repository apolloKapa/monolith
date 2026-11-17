import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Where menus open: a default, and each menu on its own if you like (a drop-down per menu).
ColumnLayout {
    id: sec
    spacing: 8
    // ── two settings: out of the bar (where along it), and else a floating place ──
    // (the bar's ends by how it sits: left and right on a bar at the top or bottom, top and bottom
    // on one down the side)
    readonly property bool sideBar: Theme.barSide !== ""
    readonly property string grows: Theme.barBottom ? "up" : (sideBar ? "in" : "down")
    readonly property var barPlaces: [["off", "Off: float (below)", "Menus open where the floating setting below says"],
                                      ["start", sideBar ? "Top of the bar" : "Left of the bar", "Grows " + grows + " out of the bar at its " + (sideBar ? "top" : "left") + " end"],
                                      ["center", "Middle of the bar", "Grows " + grows + " out of the bar, in the middle"],
                                      ["end", sideBar ? "Bottom of the bar" : "Right of the bar", "Grows " + grows + " out of the bar at its " + (sideBar ? "bottom" : "right") + " end"]]
    readonly property var places: [["center", "Middle of the screen", "A card floating in the middle"],
                                   ["top-center", "Top, under the bar", "A card at the top, the bar stays as it is"],
                                   ["bottom", "Bottom", "Slides up from the bottom edge"],
                                   ["left", "Left side", "Slides in from the left edge"],
                                   ["right", "Right side", "Slides in from the right edge"],
                                   ["top-left", "Top left corner", ""], ["top-right", "Top right corner", ""],
                                   ["bottom-left", "Bottom left corner", ""], ["bottom-right", "Bottom right corner", ""]]
    // what's set now (before there were two settings, "top" meant out of the bar, in the middle)
    readonly property string barPlace: {
        const b = String(Store.get("menus.barPlace", ""));
        if (["off", "start", "center", "end"].indexOf(b) !== -1) return b;
        return String(Store.get("menus.position", "top")) === "top" ? "center" : "off";
    }
    readonly property string floatPlace: { const p = String(Store.get("menus.position", "center")); return p === "top" ? "center" : p; }
    function setBarPlace(v) {
        Store.set("menus.barPlace", v);
        // (an old "top" floating place would mean out of the bar again: put it in the middle)
        if (String(Store.get("menus.position", "")) === "top") Store.set("menus.position", "center");
    }
    // each menu can follow the default or have its own place
    readonly property var withDefault: [["", "Same as the default", ""]]
        .concat(barPlaces.slice(1).map(p => ["bar-" + p[0], "Out of the bar: " + p[1].replace(" of the bar", "").toLowerCase(), p[2]]))
        .concat(places)
    readonly property var menus: [
        ["search", "Launcher (Search)", "search"], ["quick", "Control center", "page_info"], ["notifications", "Notifications", "notifications"],
        ["media", "Media", "music_note"], ["calendar", "Calendar & weather", "calendar_month"], ["sound", "Sound", "volume_up"],
        ["network", "Network", "wifi"], ["clipboard", "Clipboard", "content_paste"], ["windows", "Windows", "select_window"],
        ["capture", "Capture", "screenshot_region"], ["gaming", "Gaming", "sports_esports"], ["tools", "Tools", "construction"],
        ["wellbeing", "Wellbeing", "self_improvement"], ["keys", "Keybinds", "keyboard_command_key"], ["settings", "Settings", "settings"]
    ]

    SettingRow {
        key: "menus.tabs"; def: false;
        icon: "tab"; title: "Menus share one window with tabs"
        desc: "Off: the launcher, notifications, control center and the rest each open on their own. On: one window with a tab for each, Tab switches"
        Toggle { checked: Store.get("menus.tabs", false) === true; onToggled: on => Store.set("menus.tabs", on) }
    }
    SettingRow {
        keys: ["menus.barPlace"]
        icon: Theme.barBottom ? "vertical_align_top" : "vertical_align_bottom"; title: "Out of the bar"
        desc: sec.barPlace === "off" ? "Off: menus float, where the setting below says" : "Menus grow out of the bar, all one shape with it, and move with a little spring"
        Dropdown { width: 260; opts: sec.barPlaces; value: sec.barPlace; onPicked: v => sec.setBarPlace(v) }
    }
    SettingRow {
        keys: ["menus.position"]
        opacity: sec.barPlace === "off" ? 1 : 0.55
        icon: "open_in_new"; title: "Floating"
        desc: sec.barPlace === "off" ? "Where every menu appears, unless you give it its own place below" : "Used when Out of the bar is off (and by menus you set to float)"
        Dropdown { width: 260; opts: sec.places; value: sec.floatPlace; onPicked: v => Store.set("menus.position", v) }
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
                value: parent.parent.own === "top" ? "bar-center" : parent.parent.own
                onPicked: v => Store.set("menus.positions." + modelData[0], v)
            }
        }
    }
}
