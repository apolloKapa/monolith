import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Control center → Monitor: CPU, memory, GPU and temperature as rings; the disks; how far the
// internet is (a ping every few seconds while this is open).
ColumnLayout {
    id: mon
    spacing: 10
    function gb(b) { return (b / 1073741824).toFixed(1) + " GB"; }

    Card {
        cascade: true
        Layout.fillWidth: true
        Layout.preferredHeight: 200
        RowLayout {
            anchors.fill: parent
            spacing: 10
            Repeater {
                model: [
                    [Stats.cpu, Math.round(Stats.cpu * 100) + "%", "CPU", Theme.accent],
                    [Stats.mem, Math.round(Stats.mem * 100) + "%", "Memory", Theme.m("tertiary", Theme.accent)],
                    [Stats.gpu, Math.round(Stats.gpu * 100) + "%", Stats.vramTotal > 0 ? "GPU · " + mon.gb(Stats.vramUsed) : "GPU", Theme.m("secondary", Theme.accent)],
                    [Math.min(1, Math.max(Stats.temp, Stats.gpuTemp) / 100), Math.round(Stats.temp) + "°", Stats.gpuTemp > 0 ? "CPU · GPU " + Math.round(Stats.gpuTemp) + "°" : "CPU temp", Stats.temp > 80 ? Theme.danger : Theme.accent]
                ]
                Item {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Ring {
                        anchors.centerIn: parent
                        width: 150; height: 150
                        thickness: 12
                        value: parent.modelData[0]
                        text: parent.modelData[1]
                        caption: parent.modelData[2]
                        color: parent.modelData[3]
                    }
                }
            }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: 210
        spacing: 10

        // the disks: used / size as bars
        Card {
            cascade: true
            id: disks
            Layout.fillWidth: true
            Layout.preferredWidth: 640
            Layout.fillHeight: true
            icon: "hard_drive"; title: "Disks"
            property var list: []
            Process {
                running: true
                command: ["sh", "-c", "df -B1 --output=target,size,used -x tmpfs -x devtmpfs -x efivarfs -x overlay 2>/dev/null | tail -n +2"]
                stdout: StdioCollector {
                    onStreamFinished: {
                        const seen = {};
                        disks.list = text.split("\n").map(l => l.trim().split(/\s+/)).filter(p => p.length === 3)
                            .map(p => ({ at: p[0], size: Number(p[1]), used: Number(p[2]) }))
                            // one row per filesystem (btrfs subvolumes share a size)
                            .filter(d => { const k = d.size + ":" + d.used; if (seen[k] || d.size < 1e9) return false; seen[k] = true; return true; })
                            .slice(0, 4);
                    }
                }
            }
            Column {
                width: parent.width
                spacing: 12
                Repeater {
                    model: disks.list
                    Column {
                        required property var modelData
                        width: parent.width
                        spacing: 5
                        Row {
                            width: parent.width
                            Label { width: parent.width / 2; text: modelData.at; strong: true; font.pixelSize: Theme.sizeSmall + 1 }
                            Label { width: parent.width / 2; horizontalAlignment: Text.AlignRight; text: mon.gb(modelData.used) + " of " + mon.gb(modelData.size); muted: true; font.pixelSize: Theme.sizeSmall }
                        }
                        Rectangle {
                            width: parent.width; height: 8; radius: 4
                            color: Theme.ringTrack
                            Rectangle {
                                height: parent.height; radius: 4
                                width: Math.max(8, parent.width * modelData.used / Math.max(1, modelData.size))
                                color: modelData.used / modelData.size > 0.9 ? Theme.danger : Theme.accent
                            }
                        }
                    }
                }
            }
        }

        // the internet: ping to a public resolver
        Card {
            cascade: true
            id: net
            Layout.fillWidth: true
            Layout.preferredWidth: 360
            Layout.fillHeight: true
            icon: "network_ping"; title: "Internet"
            property var samples: []
            Process {
                id: ping
                command: ["sh", "-c", "ping -c1 -W2 1.1.1.1 2>/dev/null | sed -n 's/.*time=\\([0-9.]*\\).*/\\1/p'"]
                stdout: StdioCollector { onStreamFinished: { const v = parseFloat(text); net.samples = net.samples.concat([isNaN(v) ? -1 : v]).slice(-24); } }
            }
            Timer { interval: 3000; repeat: true; running: HubState.open; triggeredOnStart: true; onTriggered: ping.running = true }
            readonly property real last: samples.length > 0 ? samples[samples.length - 1] : -1
            Column {
                width: parent.width
                spacing: 8
                Text {
                    text: net.last < 0 ? (net.samples.length ? "Offline" : "…") : Math.round(net.last) + " ms"
                    color: net.last < 0 && net.samples.length ? Theme.danger : Theme.text
                    font.family: Theme.fontFamily; font.pixelSize: Theme.sizeHeadline + 4; font.weight: Font.Medium
                }
                // the last minute or so, as bars
                Row {
                    height: 54
                    spacing: 3
                    Repeater {
                        model: net.samples
                        Rectangle {
                            required property real modelData
                            width: 8
                            height: modelData < 0 ? 54 : Math.max(4, Math.min(54, modelData / 2))
                            anchors.bottom: parent.bottom
                            radius: 3
                            color: modelData < 0 ? Theme.danger : Theme.accent
                            opacity: 0.85
                        }
                    }
                }
                Label { text: "To 1.1.1.1, every 3 s"; muted: true; font.pixelSize: Theme.sizeSmall }
            }
        }
    }
}
