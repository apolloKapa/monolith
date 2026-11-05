import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// App colours: other apps take the shell's colours (from the wallpaper), kept in step when it
// changes. Switching one off takes Monolith's colours out again; your own settings stay.
ColumnLayout {
    spacing: 8
    Repeater {
        model: [
            ["kitty", "Kitty", "terminal", "The terminal's background, text and 16 colours (open windows change at once)"],
            ["gtk", "GTK apps", "web_asset", "GTK 3 and GTK 4 / libadwaita apps: accent, window and card colours (apps pick it up when they open)"],
            ["qt", "Qt apps", "widgets", "Qt apps through qt6ct and qt5ct (needs QT_QPA_PLATFORMTHEME=qt6ct, which Monolith's niri config sets)"]
        ]
        SettingRow {
            required property var modelData
            icon: modelData[2]; title: modelData[1]; desc: modelData[3]
            Toggle {
                checked: Store.get("apps." + modelData[0], false) === true
                onToggled: on => { Store.set("apps." + modelData[0], on); if (!on) AppColours.switchOff(modelData[0]); }
            }
        }
    }
    SettingRow {
        icon: "dark_mode"; title: "Dark or light apps"; desc: "Apps that only follow dark/light: Appearance → Apps follow"
        Button { text: "Appearance"; onClicked: HubState.settingsSection = "appearance" }
    }
    SettingRow {
        icon: "refresh"; title: "Write them again"; desc: "If an app lost its colours"
        Button { text: "Refresh"; onClicked: AppColours.apply() }
    }
}
