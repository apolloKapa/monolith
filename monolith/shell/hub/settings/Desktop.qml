import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Desktop widgets: arranged in the widget editor, a full-screen area where you drag, resize,
// restyle, add and remove them. (The lock screen's: Lock & idle → Arrange the lock screen)
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "dashboard_customize"; title: "Desktop widgets"
        desc: WidgetLayout.items("desktop").length + " on your desktops. Opens the editor on the screen you're on"
        Button { text: "Edit the desktop"; primary: true; icon: "edit"; onClicked: HubState.editWidgetsOn("desktop") }
    }
    SettingRow {
        key: "widgets.github.user"; def: "";
        icon: "commit"; title: "GitHub widget"; desc: "Whose contributions it shows (a GitHub username)"
        Field { width: 220; text: Store.get("widgets.github.user", ""); placeholder: "username"; onAccepted: v => Store.set("widgets.github.user", v.trim()) }
    }
    SettingRow {
        key: "widgets.imagePath"; def: "";
        icon: "image"; title: "Picture widget's picture"
        desc: (Store.get("widgets.imagePath", "") !== "" ? Store.get("widgets.imagePath", "").replace(Wall.home, "~") : "None yet") + ". For picture widgets without their own (pick one per widget in the editor, or drop a picture on it)"
        Row {
            spacing: 6
            Button { text: "Choose…"; icon: "folder_open"; primary: true; onClicked: Pictures.choose("Choose a picture for the picture widget", f => Store.set("widgets.imagePath", f)) }
            Button { visible: Store.get("widgets.imagePath", "") !== ""; text: "Clear"; onClicked: Store.unset("widgets.imagePath") }
        }
    }
    SettingRow {
        key: "widgets.shadow"; def: "off";
        icon: "widgets"; title: "Shadows under widgets"
        desc: "For every desktop and lock screen widget that doesn't pick its own (each widget's Shadow setting)"
        Segmented { width: 260; opts: [["off", "Off"], ["soft", "Soft"], ["strong", "Strong"]]; value: Theme.widgetShadow; onPicked: v => Store.set("widgets.shadow", v) }
    }
    SettingRow { icon: "keyboard"; title: "From a keybind"; desc: "monolith widgets  ·  monolith widgets lock" }
}
