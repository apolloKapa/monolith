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
        NumberBox { from: 24; to: 160; step: 2; unit: "px"; value: Number(Store.get("dock.size", 56)); onMoved: v => Store.set("dock.size", v) }
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
        icon: "push_pin"; title: "Pinned apps"; desc: "Right-click an app in the dock to pin or unpin it. Start over from the default list:"
        Button { text: "Reset"; onClicked: Store.set("dock.pinned", null) }
    }
}
