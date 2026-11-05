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
        icon: "space_dashboard"; title: "Show on empty workspaces"; desc: "Otherwise it shows only when the pointer touches the bottom edge"
        Toggle { checked: Store.get("dock.onEmpty", true); onToggled: on => Store.set("dock.onEmpty", on) }
    }
    SettingRow {
        icon: "push_pin"; title: "Pinned apps"; desc: "Right-click an app in the dock to pin or unpin it. Start over from the current Monolith's list:"
        Button { text: "Reset"; onClicked: Store.set("dock.pinned", null) }
    }
}
