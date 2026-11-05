import QtQuick
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// About: what this is, updates, and the first-launch tour again.
ColumnLayout {
    spacing: 8
    SettingRow {
        icon: "deployed_code"; title: "Monolith"; desc: "The rewritten shell, GPL-3.0. Its settings are in ~/.config/monolith/next.json"
    }
    SettingRow {
        icon: "upgrade"; title: "Updates"
        desc: Updates.state === "checking" ? "Checking…"
            : (Updates.state === "updating" ? "Updating…"
            : (Updates.state === "error" ? "Couldn't update: " + Updates.error
            : (Updates.available > 0 ? Updates.available + " new: " + Updates.log.slice(0, 3).join("; ") + (Updates.available > 3 ? "…" : "")
            : "Up to date" + (Updates.checkedAt.getTime() > 0 ? ", checked " + Qt.formatTime(Updates.checkedAt, "HH:mm") : ""))))
        Row {
            spacing: 6
            Button { text: "Check"; onClicked: Updates.check() }
            Button { visible: Updates.available > 0; text: "Update"; primary: true; onClicked: Updates.update() }
        }
    }
    SettingRow {
        icon: "autorenew"; title: "Check automatically"; desc: "Every few hours, in the background"
        Toggle { checked: Store.get("updates.check", true) !== false; onToggled: on => Store.set("updates.check", on) }
    }
    SettingRow {
        icon: "waving_hand"; title: "Welcome tour"; desc: "The first-launch setup again"
        Button { text: "Start"; onClicked: HubState.openSettings("welcome") }
    }
    SettingRow {
        icon: "keyboard_command_key"; title: "Keys"; desc: "Every keybind is on the Keys page"
        Button { text: "Open"; onClicked: HubState.page = "keys" }
    }
}
