import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// The system's usage: CPU, memory, GPU and temperature rings, the numbers behind them (memory
// and video memory used, the disk, the GPU's heat and power), a graph of the last two minutes
// of whichever you pick, and the programs using the most right now.
ColumnLayout {
    id: u
    spacing: 10
    property string graph: "cpu"
    readonly property var graphs: ({ cpu: [Stats.cpuHist, "CPU"], mem: [Stats.memHist, "Memory"], gpu: [Stats.gpuHist, "GPU"], temp: [Stats.tempHist, "Temperature"] })

    Label { text: "System"; strong: true; font.pixelSize: Theme.sizeTitle }
    GridLayout {
        Layout.fillWidth: true
        columns: 4
        columnSpacing: 6
        Repeater {
            model: [[Stats.cpu, Math.round(Stats.cpu * 100) + "%", "CPU"], [Stats.mem, Math.round(Stats.mem * 100) + "%", "Memory"],
                    [Stats.gpu, Math.round(Stats.gpu * 100) + "%", "GPU"], [Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°", "CPU temp"]]
            Ring {
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                Layout.preferredHeight: width
                Layout.maximumHeight: 110
                thickness: 8
                value: modelData[0]; text: modelData[1]; caption: modelData[2]
            }
        }
    }
    // the numbers
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 4; columnSpacing: 12
        Repeater {
            model: [["memory_alt", "Memory", Stats.bytes(Stats.memUsed) + " / " + Stats.bytes(Stats.memTotal)],
                    ["hard_drive", "Disk", Stats.bytes(Stats.diskUsed) + " / " + Stats.bytes(Stats.diskTotal)],
                    ["videogame_asset", "Video memory", Stats.vramTotal > 0 ? Stats.bytes(Stats.vramUsed) + " / " + Stats.bytes(Stats.vramTotal) : "—"],
                    ["device_thermostat", "GPU", (Stats.gpuTemp > 0 ? Math.round(Stats.gpuTemp) + "°" : "—") + (Stats.gpuWatts > 0 ? " · " + Math.round(Stats.gpuWatts) + " W" : "") + (Stats.gpuClock > 0 ? " · " + Math.round(Stats.gpuClock) + " MHz" : "")]]
            RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Icon { name: modelData[0]; size: 16; color: Theme.subtext }
                Label { text: modelData[1]; muted: true; font.pixelSize: Theme.sizeSmall }
                Label { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: modelData[2]; font.pixelSize: Theme.sizeSmall; strong: true }
            }
        }
    }
    // the last two minutes of one of them
    RowLayout {
        Layout.fillWidth: true
        Label { text: u.graphs[u.graph][1] + ", last two minutes"; muted: true; font.pixelSize: Theme.sizeSmall; Layout.fillWidth: true }
        Segmented { width: 220; height: 30; opts: [["cpu", "CPU"], ["mem", "RAM"], ["gpu", "GPU"], ["temp", "Temp"]]; value: u.graph; onPicked: v => u.graph = v }
    }
    Spark {
        Layout.fillWidth: true; Layout.preferredHeight: 64
        values: u.graphs[u.graph][0]
    }
    // what's using the most CPU now
    Label { text: "Busiest programs"; muted: true; font.pixelSize: Theme.sizeSmall }
    property var busiest: []
    Process {
        id: ps
        command: ["ps", "-eo", "pcpu,rss,comm", "--sort=-pcpu", "--no-headers"]
        stdout: StdioCollector {
            onStreamFinished: {
                // the same program's processes together (a browser is many)
                const m = {};
                for (const l of text.split("\n")) {
                    const p = l.trim().split(/\s+/);
                    if (p.length < 3) continue;
                    const n = p.slice(2).join(" ");
                    if (!m[n]) m[n] = { n: n, cpu: 0, rss: 0 };
                    m[n].cpu += parseFloat(p[0]) || 0; m[n].rss += (parseInt(p[1]) || 0) * 1024;
                }
                u.busiest = Object.values(m).sort((a, b) => b.cpu - a.cpu || b.rss - a.rss).slice(0, 6);
            }
        }
    }
    Timer { interval: 2500; running: u.visible; repeat: true; triggeredOnStart: true; onTriggered: ps.running = true }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 2
        Repeater {
            model: u.busiest
            Rectangle {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                radius: Theme.corner(28, -4)
                color: index % 2 === 0 ? Theme.container : "transparent"
                Label { x: 10; width: parent.width * 0.5; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: parent.modelData.n; font.pixelSize: Theme.sizeSmall }
                Label { anchors.right: memL.left; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: (Math.round(parent.modelData.cpu * 10) / 10) + "%"; strong: true; font.pixelSize: Theme.sizeSmall }
                Label { id: memL; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 70; horizontalAlignment: Text.AlignRight; text: Stats.bytes(parent.modelData.rss); muted: true; font.pixelSize: Theme.sizeSmall }
            }
        }
    }
    Item { Layout.fillHeight: true }
}
