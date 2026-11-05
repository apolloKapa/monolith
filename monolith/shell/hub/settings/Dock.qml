import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "dock_to_bottom"; title: "Dock"; desc: "Your pinned and open apps at the bottom of the screen"
        Toggle { checked: Store.get("dock.enabled", true); onToggled: on => Store.set("dock.enabled", on) }
    }
    SettingRow {
        icon: "space_dashboard"; title: "When it shows"; desc: "It always shows when the pointer touches the bottom edge"
        Segmented {
            width: 320
            opts: [["always", "Always"], ["empty", "Empty workspaces"], ["edge", "Only at the edge"]]
            value: Store.get("dock.show", Store.get("dock.onEmpty", true) ? "empty" : "edge")
            onPicked: v => Store.set("dock.show", v)
        }
    }
    SettingRow {
        icon: "photo_size_select_large"; title: "Size"
        NumberBox { from: 24; to: 160; slideTo: 120; step: 2; unit: "px"; value: Number(Store.get("dock.size", 56)); onMoved: v => Store.set("dock.size", v) }
    }
    SettingRow {
        icon: "zoom_in"; title: "Magnify on hover"; desc: "The app under the pointer grows"
        Toggle { checked: Store.get("dock.magnify", false) === true; onToggled: on => Store.set("dock.magnify", on) }
    }
    SettingRow {
        icon: "more_horiz"; title: "Open-window dots"; desc: "A dot under an app per open window"
        Toggle { checked: Store.get("dock.dots", true) !== false; onToggled: on => Store.set("dock.dots", on) }
    }
    SettingRow {
        icon: "apps"; title: "Open apps that aren't pinned"; desc: "Show them after the pinned ones"
        Toggle { checked: Store.get("dock.running", true) !== false; onToggled: on => Store.set("dock.running", on) }
    }
    SettingRow {
        icon: "opacity"; title: "Background"; desc: "How solid the dock is"
        NumberBox { from: 0; to: 1; step: 0.05; decimals: 2; factor: 100; unit: "%"; value: Number(Store.get("dock.opacity", 1)); onMoved: v => Store.set("dock.opacity", v) }
    }
    SettingRow {
        icon: "edit"; title: "Edit the dock"; desc: "Reorder (drag), unpin (×) and add apps (+). Or hold an app in the dock for a moment"
        Button { text: "Edit"; primary: true; icon: "edit"; onClicked: { HubState.editDock(); } }
    }
    SettingRow {
        icon: "push_pin"; title: "Pinned apps"; desc: "Right-click an app in the dock to pin or unpin it. Start over from the default list:"
        Button { text: "Reset"; onClicked: Store.set("dock.pinned", null) }
    }

    Label { text: "Where and how"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.leftMargin: 6; Layout.topMargin: 8 }
    SettingRow {
        icon: "border_bottom"; title: "Edge"
        Dropdown { opts: [["bottom", "Bottom"], ["left", "Left"], ["right", "Right"], ["top", "Top"]]; value: Store.get("dock.position", "bottom"); onPicked: v => Store.set("dock.position", v) }
    }
    SettingRow {
        icon: "fit_screen"; title: "Keep windows clear of it"; desc: "Windows leave room for the dock (it then always shows)"
        Toggle { checked: Store.get("dock.exclusive", false) === true; onToggled: on => Store.set("dock.exclusive", on) }
    }
    SettingRow {
        icon: "layers"; title: "Above fullscreen apps"
        Toggle { checked: Store.get("dock.onTop", false) === true; onToggled: on => Store.set("dock.onTop", on) }
    }
    SettingRow {
        icon: "border_style"; title: "Outline"; desc: "A thin line around it (never on a fully see-through dock)"
        Toggle { checked: Store.get("dock.border", true) !== false; onToggled: on => Store.set("dock.border", on) }
    }
    SettingRow {
        icon: "rounded_corner"; title: "Its own roundness"; desc: "Off: the theme's"
        Row {
            spacing: 8
            Toggle { anchors.verticalCenter: parent.verticalCenter; checked: Number(Store.get("dock.radius", -1)) >= 0; onToggled: on => Store.set("dock.radius", on ? 24 : -1) }
            NumberBox { visible: Number(Store.get("dock.radius", -1)) >= 0; width: 240; from: 0; to: 80; slideTo: 50; unit: "px"; value: Math.max(0, Number(Store.get("dock.radius", -1))); onMoved: v => Store.set("dock.radius", v) }
        }
    }
    SettingRow {
        icon: "vertical_align_bottom"; title: "Distance from the edge"
        NumberBox { from: 0; to: 80; slideTo: 40; unit: "px"; value: Number(Store.get("dock.margin", 12)); onMoved: v => Store.set("dock.margin", v) }
    }
    SettingRow {
        icon: "space_bar"; title: "Space between apps"
        NumberBox { from: 0; to: 30; unit: "px"; value: Number(Store.get("dock.spacing", 4)); onMoved: v => Store.set("dock.spacing", v) }
    }
    SettingRow {
        icon: "timer"; title: "Hides after"; desc: "How long it stays once the pointer leaves"
        NumberBox { from: 0; to: 5000; slideTo: 2000; step: 50; unit: "ms"; value: Number(Store.get("dock.hideDelay", 400)); onMoved: v => Store.set("dock.hideDelay", v) }
    }
    SettingRow {
        icon: "apps"; title: "Most apps shown"; desc: "0: all of them"
        NumberBox { from: 0; to: 40; slideTo: 20; zeroText: "All"; value: Number(Store.get("dock.maxApps", 0)); onMoved: v => Store.set("dock.maxApps", v) }
    }
    SettingRow {
        icon: "filter_alt"; title: "Which open apps"; desc: "The ones that aren't pinned"
        Dropdown { opts: [["all", "All of them"], ["screen", "On this screen"], ["workspace", "On this workspace"]]; value: Store.get("dock.runningScope", "all"); onPicked: v => Store.set("dock.runningScope", v) }
    }
}
