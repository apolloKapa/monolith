import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Desktop mode (core/Desk.qml): the shell as a desktop, with a taskbar, a start menu and floating
// windows. Experimental.
ColumnLayout {
    spacing: 8
    // the little "experimental" tag beside its switch
    component Tag: SmoothRect {
        // (amber, the colour of "careful": the themes have no colour of their own for it)
        readonly property color warn: "#e8a33d"
        smoothing: 0
        width: tagRow.implicitWidth + 16; height: 26
        radius: Theme.corner(26, 6)
        color: Qt.alpha(warn, 0.16)
        border.width: 1; border.color: Qt.alpha(warn, 0.5)
        Row {
            id: tagRow
            anchors.centerIn: parent
            spacing: 5
            Icon { anchors.verticalCenter: parent.verticalCenter; name: "science"; size: 15; color: parent.parent.warn }
            Label { anchors.verticalCenter: parent.verticalCenter; text: "Experimental"; font.pixelSize: Theme.sizeSmall; strong: true; color: parent.parent.warn }
        }
    }
    SettingRow {
        key: "desktop.enabled"; def: false;
        icon: "desktop_windows"; title: "Desktop mode"
        desc: "Monolith as a desktop: the bar and the dock join into one taskbar, the launcher becomes a start menu, and windows float with their own title bars. Still being worked on: some things may not be quite right yet"
        Row {
            spacing: 12
            Tag { anchors.verticalCenter: parent.verticalCenter }
            Toggle { anchors.verticalCenter: parent.verticalCenter; checked: Store.raw("desktop.enabled", false) === true; onToggled: on => Store.set("desktop.enabled", on) }
        }
    }
    SettingRow {
        key: "desktop.edge"; def: "dock";
        icon: "dock_to_bottom"; title: "Where the taskbar goes"
        desc: "Where the dock is: the bar comes to the dock. Where the bar is: the dock goes up to the bar"
        Dropdown {
            width: 230
            opts: [["dock", "Where the dock is"], ["bar", "Where the bar is"], ["bottom", "Bottom"], ["top", "Top"], ["left", "Left side"], ["right", "Right side"]]
            value: String(Store.raw("desktop.edge", "dock"))
            onPicked: v => Store.set("desktop.edge", v)
        }
    }
    SettingRow {
        key: "desktop.appsAt"; def: "center";
        icon: "align_horizontal_center"; title: "Apps on the taskbar"
        desc: "In the middle with the start button, or at the start of the taskbar"
        Dropdown {
            width: 230
            opts: [["center", "In the middle"], ["start", "At the start"]]
            value: Desk.appsAt
            onPicked: v => Store.set("desktop.appsAt", v)
        }
    }
    SettingRow {
        key: "desktop.height"; def: 48;
        icon: "height"; title: "Taskbar size"
        NumberBox { from: 40; to: 72; step: 2; unit: "px"; value: Desk.size; onMoved: v => Store.set("desktop.height", v) }
    }
    SettingRow {
        key: "desktop.floating"; def: true;
        icon: "picture_in_picture"; title: "Windows float"
        desc: "Windows open floating, like on a desktop, and the ones already open float too (they go back into their tiles when Desktop mode is off). Each app's windows open as big as you last made them"
        Toggle { checked: Desk.floating; onToggled: on => Store.set("desktop.floating", on) }
    }
    SettingRow {
        key: "desktop.sizes";
        icon: "aspect_ratio"; title: "Remembered window sizes"
        desc: Object.keys(Desk.sizes).length === 0 ? "None yet: resize a window and the next one of that app opens that big" : Object.keys(Desk.sizes).length + " apps open at the size you last made them"
        Button { visible: Object.keys(Desk.sizes).length > 0; text: "Forget them"; onClicked: Store.unset("desktop.sizes") }
    }
    SettingRow {
        key: "desktop.titlebars"; def: true;
        icon: "web_asset"; title: "Title bars"
        desc: Niri.hyprland
            ? (Desk.barsReady ? "Every window gets a title bar like a desktop's: its name, minimise, maximise and close, a double click maximises, drag it to move the window"
                              : "Apps that draw their own title bars (GTK apps, browsers) get minimise, maximise and close. For a bar on every window, Hyprland needs a plugin: below")
            : "Apps draw their own title bars, with minimise, maximise and close (niri's prefer-no-csd is off meanwhile). Apps open before you switched get theirs once they're opened again"
        Toggle { checked: Desk.titlebars; onToggled: on => Store.set("desktop.titlebars", on) }
    }
    // Hyprland: the hyprbars plugin, built here (scripts/hyprbars.sh)
    SettingRow {
        show: Niri.hyprland
        icon: "build"; title: "Title bars on every window"
        desc: Desk.barsState === "ready" ? "Built for this Hyprland (the hyprbars plugin, from Hyprland's own plugins). Build it again after Hyprland updates"
            : Desk.barsState === "old" ? "Built for another Hyprland version: build it again for this one"
            : "Hyprland draws no title bars itself: this builds its hyprbars plugin from Hyprland's own plugins, in a terminal (a minute or so, no password)"
        Button {
            text: Desk.barsState === "ready" ? "Build again" : (Desk.barsState === "old" ? "Build again" : "Build")
            icon: "build"; primary: Desk.barsState !== "ready"
            onClicked: Desk.buildBars()
        }
    }
    SettingRow {
        key: "desktop.noBar"
        show: Niri.hyprland && Desk.barsReady
        icon: "web_asset_off"; title: "No title bar for"
        desc: "Apps that draw their own bar (browsers, GNOME apps, Discord…), by app id, separated by commas. * matches anything"
        Field {
            width: 300
            text: Desk.noBar.join(", ")
            onAccepted: v => Store.set("desktop.noBar", v.split(",").map(x => x.trim()).filter(x => x !== ""))
        }
    }
    SettingRow {
        icon: "minimize"; title: "Minimising"
        desc: "Click an app on the taskbar to minimise its window, and again to bring it back. Right-click it for its windows, maximise and close"
    }
    SettingRow {
        icon: "info"; title: "Your bar and dock"
        desc: "Desktop mode doesn't change their settings: the taskbar keeps your bar's style (Bar → Style), and it only stands in for where the bar is, how tall it is and its middle while it's on. They're as you left them when it's off"
    }
}
