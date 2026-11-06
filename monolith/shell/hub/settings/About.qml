import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// About: what this is, updates, and the first-launch tour again.
ColumnLayout {
    id: sec
    spacing: 8
    property var info: ({})
    Process {
        running: true
        command: ["sh", "-c", ". /etc/os-release; echo \"os=$PRETTY_NAME\"; echo \"kernel=$(uname -r)\"; echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')\"; echo \"gpu=$(lspci 2>/dev/null | grep -i -m1 -E 'vga|3d|display' | sed 's/.*: //; s/ (rev.*//')\"; echo \"mem=$(awk '/MemTotal/{printf \"%.0f GB\", $2/1048576}' /proc/meminfo)\"; echo \"niri=$(niri --version 2>/dev/null)\"; echo \"qs=$(quickshell --version 2>/dev/null | head -1 | cut -d' ' -f2)\""]
        stdout: StdioCollector { onStreamFinished: { const o = {}; for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.substring(0, i)] = l.substring(i + 1); } sec.info = o; } }
    }
    SettingRow {
        icon: "deployed_code"; title: "Monolith " + Updates.version; desc: "A desktop shell for niri. GPL-3.0. Its settings are in ~/.config/monolith/next.json"
        Button { text: "GitHub"; icon: "open_in_new"; onClicked: Quickshell.execDetached(["xdg-open", "https://github.com/apolloKapa/monolith"]) }
    }
    Card {
        Layout.fillWidth: true
        Layout.preferredHeight: 190
        icon: "computer"; title: "This PC"
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: [["System", "os"], ["Kernel", "kernel"], ["CPU", "cpu"], ["GPU", "gpu"], ["Memory", "mem"], ["niri · Quickshell", "niri"]]
                Row {
                    required property var modelData
                    width: parent.width
                    Label { width: 140; text: modelData[0]; muted: true; font.pixelSize: Theme.sizeSmall + 1 }
                    Label { width: parent.width - 140; text: modelData[1] === "niri" ? (sec.info.niri || "") + "  ·  Quickshell " + (sec.info.qs || "") : (sec.info[modelData[1]] || "…"); font.pixelSize: Theme.sizeSmall + 1 }
                }
            }
        }
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
        Button { text: "Show it"; onClicked: HubState.openWelcome() }
    }
    SettingRow {
        icon: "keyboard_command_key"; title: "Keys"; desc: "Every keybind is on the Keys page"
        Button { text: "Open"; onClicked: HubState.page = "keys" }
    }
}
