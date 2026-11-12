import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Control center → Overview: the weather, this month, the latest clipboard entries and this
// PC at a glance.
GridLayout {
    id: ov
    columns: 2
    rowSpacing: 10
    columnSpacing: 10

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // ── weather: now, big; then the next hours ──
    Card {
        cascade: true
        Layout.fillWidth: true
        Layout.preferredHeight: 230
        icon: "partly_cloudy_day"; title: Weather.city !== "" ? Weather.city : "Weather"
        Column {
            width: parent.width
            spacing: 12
            visible: Weather.ready
            Row {
                spacing: 14
                Icon { name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : "cloud"; size: 54; filled: true; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : ""; color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeDisplay - 6; font.weight: Font.Medium }
                    Label { text: Weather.ready ? Weather.describe(Weather.current.code) : ""; muted: true }
                }
            }
            Row {
                width: parent.width
                Repeater {
                    model: Weather.hours.filter((h, i) => i % 3 === 0).slice(1, 7)
                    Column {
                        required property var modelData
                        width: parent.width / 6
                        spacing: 3
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: modelData.time; muted: true; font.pixelSize: Theme.sizeSmall }
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: Weather.icon(modelData.code, true); size: 20; color: Theme.subtext }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: Math.round(modelData.temp) + "°"; strong: true; font.pixelSize: Theme.sizeSmall + 1 }
                    }
                }
            }
        }
        Label { visible: !Weather.ready; width: parent.width; wrapMode: Text.Wrap; text: Weather.loc ? "Getting the weather…" : "No weather yet: set your city in Settings → General → You & weather"; muted: true }
    }

    // ── this month, today filled ──
    Card {
        cascade: true
        id: cal
        Layout.fillWidth: true
        Layout.preferredHeight: 230
        icon: "calendar_month"; title: Qt.formatDate(clock.date, "MMMM yyyy")
        readonly property date now: clock.date
        readonly property int first: (new Date(now.getFullYear(), now.getMonth(), 1).getDay() + 6) % 7
        readonly property int days: new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate()
        Row {
            width: parent.width
            spacing: 16
            // the date, big
            Column {
                width: 92
                Text { text: Qt.formatDate(cal.now, "d"); color: Theme.accent; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeDisplay + 8; font.weight: Font.Bold }
                Label { text: Qt.formatDate(cal.now, "dddd"); strong: true }
                Label { text: "Week " + Math.ceil(((cal.now - new Date(cal.now.getFullYear(), 0, 1)) / 86400000 + new Date(cal.now.getFullYear(), 0, 1).getDay() + 1) / 7); muted: true; font.pixelSize: Theme.sizeSmall }
            }
            Grid {
                columns: 7
                readonly property real cw: (parent.width - 92 - 16) / 7
                Repeater {
                    model: ["M", "T", "W", "T", "F", "S", "S"]
                    Label { required property string modelData; width: parent.cw; height: 20; horizontalAlignment: Text.AlignHCenter; text: modelData; muted: true; font.pixelSize: Theme.sizeSmall - 1 }
                }
                Repeater {
                    model: cal.first + cal.days
                    Item {
                        required property int index
                        readonly property int day: index - cal.first + 1
                        readonly property bool today: day === cal.now.getDate()
                        width: parent.cw; height: 24
                        Rectangle { anchors.centerIn: parent; width: 24; height: 24; radius: 12; visible: parent.today; color: Theme.accent }
                        Label { anchors.centerIn: parent; visible: parent.day > 0; text: parent.day; color: parent.today ? Theme.onAccent : Theme.text; strong: parent.today; font.pixelSize: Theme.sizeSmall }
                    }
                }
            }
        }
        MouseArea { anchors.fill: parent; cursorShape: Qt.PointingHandCursor; onClicked: HubState.page = "calendar" }
    }

    // ── the latest clipboard entries (click one to copy it again) ──
    Card {
        cascade: true
        id: clip
        Layout.fillWidth: true
        Layout.preferredHeight: 230
        icon: "content_paste"; title: "Clipboard"
        property var entries: []
        Process {
            running: true
            command: ["sh", "-c", "cliphist list 2>/dev/null | head -4"]
            stdout: StdioCollector { onStreamFinished: clip.entries = text.split("\n").filter(l => l).map(l => ({ line: l, text: l.substring(l.indexOf("\t") + 1) })) }
        }
        Column {
            width: parent.width
            spacing: 6
            Repeater {
                model: clip.entries
                Pressable {
                    required property var modelData
                    width: parent.width
                    height: 36
                    radius: Theme.corner(36, 2)
                    color: Theme.containerHigh
                    onClicked: { Quickshell.execDetached(["sh", "-c", "printf '%s' \"$1\" | cliphist decode | wl-copy", "_", modelData.line]); HubState.close(); }
                    Label {
                        x: 12; width: parent.width - 24
                        anchors.verticalCenter: parent.verticalCenter
                        text: /^\[\[ binary data/.test(parent.modelData.text) ? "Image" : parent.modelData.text.replace(/\s+/g, " ")
                        font.pixelSize: Theme.sizeSmall + 1
                    }
                }
            }
            Label { visible: clip.entries.length === 0; text: "Nothing copied yet"; muted: true }
        }
    }

    // ── this PC ──
    Card {
        cascade: true
        id: sys
        Layout.fillWidth: true
        Layout.preferredHeight: 230
        icon: "computer"; title: "This PC"
        property var info: ({})
        Process {
            running: true
            command: ["sh", "-c", ". /etc/os-release; echo \"os=$PRETTY_NAME\"; echo \"host=$(cat /etc/hostname 2>/dev/null || uname -n)\"; echo \"kernel=$(uname -r)\"; echo \"cpu=$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2 | sed 's/^ *//')\"; echo \"mem=$(awk '/MemTotal/{printf \"%.0f GB\", $2/1048576}' /proc/meminfo)\""]
            stdout: StdioCollector {
                onStreamFinished: {
                    const o = {};
                    for (const l of text.split("\n")) { const i = l.indexOf("="); if (i > 0) o[l.substring(0, i)] = l.substring(i + 1); }
                    sys.info = o;
                }
            }
        }
        Column {
            width: parent.width
            spacing: 7
            Repeater {
                model: [["dns", "Host", "host"], ["deployed_code", "System", "os"], ["memory", "Kernel", "kernel"], ["developer_board", "CPU", "cpu"], ["data_usage", "Memory", "mem"]]
                Row {
                    required property var modelData
                    width: parent.width
                    spacing: 10
                    Icon { name: modelData[0]; size: 17; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: 70; text: modelData[1]; muted: true; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                    Label { width: parent.width - 100; text: sys.info[modelData[2]] || "…"; font.pixelSize: Theme.sizeSmall + 1; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
