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
        // out of a side of the screen: through the frame in the Frame style, one piece with it
        .concat([["left", "Left side of the screen", "Slides out of the screen's left side" + frameWord],
                 ["right", "Right side of the screen", "Slides out of the screen's right side" + frameWord],
                 ["bottom", "Bottom of the screen", "Slides up out of the screen's bottom" + frameWord]].filter(p => p[0] !== Theme.barEdge))
    readonly property string frameWord: Theme.barStyle === "frame" ? ", through the frame" : ""
    readonly property var outPlaces: ["off", "start", "center", "end", "left", "right", "bottom"]
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
        if (outPlaces.indexOf(b) !== -1) return b;
        return String(Store.get("menus.position", "top")) === "top" ? "center" : "off";
    }
    readonly property string floatPlace: { const p = String(Store.get("menus.position", "center")); return p === "top" ? "center" : p; }
    function setBarPlace(v) {
        Store.set("menus.barPlace", v);
        // (an old "top" floating place would mean out of the bar again: put it in the middle)
        if (String(Store.get("menus.position", "")) === "top") Store.set("menus.position", "center");
    }
    // each menu can follow the defaults or have its own two: out of the bar, and floating
    readonly property var barOwn: [["same", "Same as the default", ""], ["off", "Off: float", ""]].concat(barPlaces.slice(1))
    readonly property var floatOwn: [["", "Same as the default", ""]].concat(places)
    // what a menu has now ([out of the bar, floating]); from before each had the two, its one
    // setting held either ("bar-…", or a floating place that also meant not out of the bar)
    function ownOf(id) {
        const own = String(Store.get("menus.positions." + id, "") || "");
        const ownBar = String(Store.get("menus.barPlaces." + id, "") || "");
        const fl = own !== "" && own !== "top" && !own.startsWith("bar-") ? own : "";
        let bar = "same";
        if (ownBar === "same" || outPlaces.indexOf(ownBar) !== -1) bar = ownBar;
        else if (own === "top") bar = "center";
        else if (own.startsWith("bar-")) bar = own.slice(4);
        else if (fl !== "") bar = "off";
        return [bar, fl];
    }
    function setOwn(id, bar, fl) {
        if (bar === "same") Store.unset("menus.barPlaces." + id); else Store.set("menus.barPlaces." + id, bar);
        // (kept even when "same": an old one-setting value would be read the old way without it)
        if (bar === "same" && fl !== "") Store.set("menus.barPlaces." + id, "same");
        if (fl === "") Store.unset("menus.positions." + id); else Store.set("menus.positions." + id, fl);
    }
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
        icon: Theme.barBottom ? "vertical_align_top" : "vertical_align_bottom"; title: Theme.barStyle === "frame" ? "Out of the bar or the frame" : "Out of the bar or a side"
        desc: sec.barPlace === "off" ? "Off: menus float, where the setting below says"
            : (["left", "right", "bottom"].indexOf(sec.barPlace) !== -1 ? (sec.barPlaces.find(p => p[0] === sec.barPlace) || ["", "", ""])[2] + ", all one shape with it"
            : "Menus grow out of the bar, all one shape with it, and move with a little spring")
        Dropdown { width: 260; opts: sec.barPlaces; value: sec.barPlace; onPicked: v => sec.setBarPlace(v) }
    }
    SettingRow {
        keys: ["menus.position"]
        opacity: sec.barPlace === "off" ? 1 : 0.55
        icon: "open_in_new"; title: "Floating"
        desc: sec.barPlace === "off" ? "Where every menu appears, unless you give it its own place below" : "Used when Out of the bar is off (and by menus you set to float)"
        Dropdown { width: 260; opts: sec.places; value: sec.floatPlace; onPicked: v => Store.set("menus.position", v) }
    }
    SettingRow {
        key: "menus.edgeHover"; def: false
        icon: "left_click"; title: "Open by hovering the edge"
        desc: "A menu set to come out of the left, right or bottom of the screen opens when the pointer rests on the middle of that edge, and closes a moment after the pointer leaves it. One menu per side: the first in the list below"
        Toggle { checked: Store.get("menus.edgeHover", false) === true; onToggled: on => Store.set("menus.edgeHover", on) }
    }
    // Monolith's own menus and lists (ui/SmoothWheel), on top of the mouse's speed; works on any
    // compositor (Monolith's setting)
    SettingRow {
        key: "menus.scrollSpeed"; def: 1
        icon: "menu_open"; title: "Menu scroll speed"; desc: "How far one notch scrolls Monolith's menus, Settings and lists, on top of the mouse scroll speed. 1× is normal"
        NumberBox {
            from: 0.25; to: 4; slideTo: 3; step: 0.05; decimals: 2; unit: "×"
            value: Number(Store.get("menus.scrollSpeed", 1))
            onMoved: x => Store.set("menus.scrollSpeed", Number(x.toFixed(2)))
        }
    }
    Label { text: "Each menu"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 6 }
    Label {
        Layout.fillWidth: true; Layout.leftMargin: 6; wrapMode: Text.Wrap; muted: true; font.pixelSize: Theme.sizeSmall
        text: "Two choices for each, like the defaults above: out of the bar (first), and where it floats when it isn't (second)"
    }
    Repeater {
        model: sec.menus
        SettingRow {
            id: mr
            required property var modelData
            readonly property var own: { Store.revision; return sec.ownOf(modelData[0]); }
            // where it ends up, in words
            readonly property string barNow: own[0] === "same" ? sec.barPlace : own[0]
            keys: ["menus.barPlaces." + modelData[0], "menus.positions." + modelData[0]]
            icon: modelData[2]; title: modelData[1]
            desc: own[0] === "same" && own[1] === "" ? "Follows the defaults"
                : (barNow !== "off" ? "Out of the bar" : "Floats: " + ((sec.places.find(p => p[0] === (own[1] !== "" ? own[1] : sec.floatPlace)) || ["", "the default place"])[1]).toLowerCase())
            Row {
                spacing: 6
                Dropdown {
                    width: 196
                    opts: sec.barOwn
                    value: mr.own[0]
                    onPicked: v => sec.setOwn(mr.modelData[0], v, mr.own[1])
                }
                Dropdown {
                    width: 210
                    opacity: mr.barNow === "off" ? 1 : 0.55
                    opts: sec.floatOwn
                    value: mr.own[1]
                    onPicked: v => sec.setOwn(mr.modelData[0], mr.own[0], v)
                }
            }
        }
    }
}
