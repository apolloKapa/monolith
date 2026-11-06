import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// Desktop widgets and the lock screen's: both arranged in the widget editor, a full-screen
// area where you drag, resize, restyle, add and remove them.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "dashboard_customize"; title: "Desktop widgets"
        desc: WidgetLayout.items("desktop").length + " on your desktops. Opens the editor on the screen you're on"
        Button { text: "Edit the desktop"; primary: true; icon: "edit"; onClicked: HubState.editWidgetsOn("desktop") }
    }
    SettingRow {
        icon: "lock"; title: "Lock screen widgets"
        desc: WidgetLayout.items("lock").length + " on the lock screen (the password box stays where it is)"
        Button { text: "Edit the lock screen"; primary: true; icon: "edit"; onClicked: HubState.editWidgetsOn("lock") }
    }
    SettingRow {
        key: "widgets.github.user"; def: "";
        icon: "commit"; title: "GitHub widget"; desc: "Whose contributions it shows (a GitHub username)"
        Field { width: 220; text: Store.get("widgets.github.user", ""); placeholder: "username"; onAccepted: v => Store.set("widgets.github.user", v.trim()) }
    }
    SettingRow {
        key: "widgets.imagePath"; def: "";
        icon: "image"; title: "Picture widget"; desc: "An image file"
        Field { text: Store.get("widgets.imagePath", ""); placeholder: "/path/to/picture.png"; onAccepted: v => { const p = v.trim().replace(/^~/, Wall.home); if (p !== Store.get("widgets.imagePath", "")) Store.set("widgets.imagePath", p); } }
    }
    SettingRow { icon: "keyboard"; title: "From a keybind"; desc: "monolith widgets  ·  monolith widgets lock" }
}
