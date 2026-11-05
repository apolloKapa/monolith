import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Bar → Screens: which screens have the bar (and the dock). Menus still open on a screen
// without a bar.
ColumnLayout {
    spacing: 8
    readonly property var barOff: Store.get("bar.hiddenScreens", []) || []
    readonly property var dockOff: Store.get("dock.hiddenScreens", []) || []
    Label { Layout.fillWidth: true; wrapMode: Text.Wrap; text: "Pick where the bar and the dock show. Menus and notifications still open on every screen."; muted: true }
    Repeater {
        model: Quickshell.screens
        Card {
            id: sc
            required property var modelData
            readonly property bool barOn: parent.barOff.indexOf(modelData.name) === -1
            readonly property bool dockOn: parent.dockOff.indexOf(modelData.name) === -1
            Layout.fillWidth: true
            Layout.preferredHeight: 190
            icon: "monitor"
            title: modelData.name + (modelData.model ? "  ·  " + ((modelData.manufacturer || "") + " " + modelData.model).trim() : "") + "  ·  " + modelData.width + " × " + modelData.height
            Column {
                width: parent.width
                spacing: 8
                SettingRow {
                    width: parent.width
                    icon: "toolbar"; title: "Bar on this screen"
                    Toggle {
                        checked: sc.barOn
                        onToggled: on => { const l = Store.get("bar.hiddenScreens", []) || []; Store.set("bar.hiddenScreens", on ? l.filter(x => x !== sc.modelData.name) : l.concat([sc.modelData.name])); }
                    }
                }
                SettingRow {
                    width: parent.width
                    icon: "dock_to_bottom"; title: "Dock on this screen"
                    Toggle {
                        checked: sc.dockOn
                        onToggled: on => { const l = Store.get("dock.hiddenScreens", []) || []; Store.set("dock.hiddenScreens", on ? l.filter(x => x !== sc.modelData.name) : l.concat([sc.modelData.name])); }
                    }
                }
            }
        }
    }
}
