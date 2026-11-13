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
        command: ["sh", "-c", ". /etc/os-release; echo \"os=$PRETTY_NAME\"; echo \"kernel=$(uname -r)\"; echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')\"; echo \"gpu=$(lspci 2>/dev/null | grep -i -m1 -E 'vga|3d|display' | sed 's/.*: //; s/ (rev.*//')\"; echo \"mem=$(awk '/MemTotal/{printf \"%.0f GB\", $2/1048576}' /proc/meminfo)\"; echo \"niri=$(if [ -n \"$HYPRLAND_INSTANCE_SIGNATURE\" ]; then hyprctl version 2>/dev/null | head -1 | cut -c1-40; else niri --version 2>/dev/null; fi)\"; echo \"qs=$(quickshell --version 2>/dev/null | head -1 | cut -d' ' -f2)\""]
        stdout: StdioCollector { onStreamFinished: { const o = {}; for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.substring(0, i)] = l.substring(i + 1); } sec.info = o; } }
    }
    SettingRow {
        icon: "deployed_code"; title: "Monolith " + Updates.version; desc: "A desktop shell for niri and Hyprland. GPL-3.0. Its settings are in ~/.config/monolith/next.json"
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
                model: [["System", "os"], ["Kernel", "kernel"], ["CPU", "cpu"], ["GPU", "gpu"], ["Memory", "mem"], [Niri.compositor + " · Quickshell", "niri"]]
                Row {
                    required property var modelData
                    width: parent.width
                    Label { width: 140; text: modelData[0]; muted: true; font.pixelSize: Theme.sizeSmall + 1 }
                    Label { width: parent.width - 140; text: modelData[1] === "niri" ? (sec.info.niri || "") + "  ·  Quickshell " + (sec.info.qs || "") : (sec.info[modelData[1]] || "…"); font.pixelSize: Theme.sizeSmall + 1 }
                }
            }
        }
    }
    // ── updates ──
    Rectangle {
        id: upd
        Layout.fillWidth: true
        implicitHeight: ucol.implicitHeight + 36
        radius: Theme.corner(96, 8)
        color: Updates.newer ? Theme.accentContainer : Theme.containerHigh
        border.width: Theme.outlineW; border.color: Theme.outlineColor
        readonly property color ink: Updates.newer ? Theme.onAccentContainer : Theme.text
        Column {
            id: ucol
            x: 18; y: 18; width: parent.width - 36
            spacing: 12
            RowLayout {
                width: parent.width
                spacing: 14
                Rectangle {
                    width: 52; height: 52; radius: Theme.corner(52)
                    color: Updates.newer ? Theme.accent : Theme.control
                    Icon {
                        id: updIcon
                        anchors.centerIn: parent
                        name: Updates.state === "checking" || Updates.state === "updating" ? "progress_activity" : (Updates.newer ? "upgrade" : (Updates.state === "offline" ? "cloud_off" : "verified"))
                        filled: true; size: 28
                        color: Updates.newer ? Theme.onAccent : Theme.accent
                        RotationAnimation on rotation { running: Updates.state === "checking" || Updates.state === "updating"; from: 0; to: 360; duration: 900; loops: Animation.Infinite; onRunningChanged: if (!running) updIcon.rotation = 0 }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        Layout.fillWidth: true
                        text: Updates.state === "updating" ? "Updating…"
                            : Updates.state === "checking" ? "Looking for updates…"
                            : Updates.newer ? "A new version is here" + (Updates.newVersion && ["new", "git", Updates.version].indexOf(Updates.newVersion) === -1 ? ": " + Updates.newVersion : "")
                            : Updates.state === "offline" ? "Couldn't reach GitHub"
                            : "Monolith is up to date"
                        color: upd.ink; font.family: Theme.fontFamily; font.pixelSize: 19; font.weight: Font.Bold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        wrapMode: Text.Wrap
                        text: Updates.state === "updating" ? "It's running in the terminal that opened; Monolith restarts when it's done."
                            : "You have " + (Updates.version || "?") + (Updates.newer ? (Updates.available > 1 || Updates.log.length ? "  ·  " + Updates.log.length + (Updates.log.length === 1 ? " change" : " changes") + " since" : "") : "")
                              + (Updates.checkedAt.getTime() > 0 ? "  ·  checked " + Qt.formatTime(Updates.checkedAt, "HH:mm") : "")
                              + (Updates.state === "offline" ? "  ·  check your connection" : "")
                        color: Qt.alpha(upd.ink, 0.75); font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall + 1
                    }
                }
                Button {
                    visible: !Updates.newer
                    text: "Check for updates"; icon: "refresh"
                    enabled: Updates.state !== "checking"
                    onClicked: Updates.check()
                }
                Button {
                    visible: Updates.newer
                    text: Updates.state === "updating" ? "Updating…" : "Update now"; icon: "download"; primary: true
                    enabled: Updates.state !== "updating"
                    onClicked: Updates.update()
                }
            }
            // what changed, newest first
            Rectangle {
                visible: Updates.newer && Updates.log.length > 0
                width: parent.width
                height: Math.min(changes.implicitHeight + 20, 220)
                radius: Theme.corner(60, 6)
                color: Qt.alpha(Theme.frame, 0.55)
                Flickable {
                    anchors.fill: parent; anchors.margins: 10
                    contentHeight: changes.implicitHeight
                    clip: true
                    SmoothWheel {}
                    Column {
                        id: changes
                        width: parent.width
                        spacing: 6
                        Label { text: "What's new"; strong: true; font.pixelSize: Theme.sizeSmall; color: upd.ink }
                        Repeater {
                            model: Updates.log.slice().reverse()
                            Row {
                                required property string modelData
                                width: changes.width
                                spacing: 8
                                Rectangle { width: 6; height: 6; radius: 3; color: Theme.accent; y: 7 }
                                Text { width: parent.width - 14; text: modelData; wrapMode: Text.Wrap; color: upd.ink; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeSmall }
                            }
                        }
                    }
                }
            }
        }
    }
    SettingRow {
        key: "updates.check"; def: true;
        icon: "autorenew"; title: "Check automatically"; desc: "Every few hours, in the background"
        Toggle { checked: Store.get("updates.check", true) !== false; onToggled: on => Store.set("updates.check", on) }
    }
    SettingRow {
        icon: "waving_hand"; title: "Welcome tour"; desc: "The first-launch setup again"
        Button { text: "Show it"; onClicked: HubState.openWelcome() }
    }
    SettingRow {
        icon: "keyboard_command_key"; title: "Keybinds"; desc: "Every keybind is on the Keys page"
        Button { text: "Open"; onClicked: HubState.go("keys") }
    }
}
