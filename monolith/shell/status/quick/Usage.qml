import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// The system's usage: CPU, memory, GPU and temperature rings, the numbers behind them (memory
// and video memory used, the disk, the GPU's heat and power: click one to copy it), a graph of
// the last two minutes of whichever you pick (with its average and peak), and the programs using
// the most right now. Copy puts all of it on the clipboard as text; a snapshot keeps it in the
// history (with the time) to look at or copy later. Wide, the programs and the history get a
// column of their own.
GridLayout {
    id: u
    columns: wide ? 2 : 1
    columnSpacing: 14
    rowSpacing: 10
    readonly property bool wide: width > 760
    property string graph: "cpu"
    readonly property var graphs: ({ cpu: [Stats.cpuHist, "CPU"], mem: [Stats.memHist, "Memory"], gpu: [Stats.gpuHist, "GPU"], temp: [Stats.tempHist, "Temperature"] })
    readonly property var gv: graphs[graph][0] || []
    readonly property real avg: gv.length ? gv.reduce((a, b) => a + b, 0) / gv.length : 0
    readonly property real peak: gv.length ? Math.max(...gv) : 0
    function fmtG(v) { return graph === "temp" ? Math.round(v * 100) + "°" : Math.round(v * 100) + "%"; }
    property bool showHistory: false
    readonly property var snapshots: Store.get("quick.usageSnapshots", []) || []
    function copy(t) { Quickshell.execDetached(["wl-copy", "--", t]); }

    readonly property var facts: [["memory_alt", "Memory", Stats.bytes(Stats.memUsed) + " / " + Stats.bytes(Stats.memTotal)],
        ["hard_drive", "Disk", Stats.bytes(Stats.diskUsed) + " / " + Stats.bytes(Stats.diskTotal)],
        ["videogame_asset", "Video memory", Stats.vramTotal > 0 ? Stats.bytes(Stats.vramUsed) + " / " + Stats.bytes(Stats.vramTotal) : "—"],
        ["device_thermostat", "GPU", (Stats.gpuTemp > 0 ? Math.round(Stats.gpuTemp) + "°" : "—") + (Stats.gpuWatts > 0 ? " · " + Math.round(Stats.gpuWatts) + " W" : "") + (Stats.gpuClock > 0 ? " · " + Math.round(Stats.gpuClock) + " MHz" : "")]]
    // all of it, as text
    function report() {
        const l = ["CPU " + Math.round(Stats.cpu * 100) + "% · " + Math.round(Stats.temp) + "°", "Memory " + Math.round(Stats.mem * 100) + "% (" + facts[0][2] + ")",
                   "GPU " + Math.round(Stats.gpu * 100) + "% · " + facts[3][2], "Video memory " + facts[2][2], "Disk " + facts[1][2]];
        if (busiest.length) l.push("Busiest: " + busiest.slice(0, 5).map(p => p.n + " " + (Math.round(p.cpu * 10) / 10) + "%").join(", "));
        return l.join("\n");
    }
    function snapshot() { Store.set("quick.usageSnapshots", [{ at: Date.now(), text: report() }].concat(snapshots).slice(0, 40)); }

    component CopyBtn: Pressable {
        property string what: ""
        width: 26; height: 26
        color: hovered ? Theme.control : "transparent"
        onClicked: u.copy(what)
        Icon { anchors.centerIn: parent; name: "content_copy"; size: 14; color: Theme.subtext }
    }
    component SmallBtn: Pressable {
        id: sb
        property string icon: ""
        property string text: ""
        property bool on: false
        width: sbl.implicitWidth + (icon !== "" ? 40 : 20) - (text === "" ? 14 : 0); height: 30
        color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.control)
        Row { anchors.centerIn: parent; spacing: 4
            Icon { visible: sb.icon !== ""; name: sb.icon; size: 15; color: sb.on ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter }
            Label { id: sbl; visible: sb.text !== ""; text: sb.text; font.pixelSize: Theme.sizeSmall; color: sb.on ? Theme.onAccentContainer : Theme.text; anchors.verticalCenter: parent.verticalCenter } }
    }

    // ── now ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 3
        Layout.maximumWidth: u.wide ? 760 : -1
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 6
            Label { text: u.showHistory && !u.wide ? "Snapshots" : "System"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
            SmallBtn { icon: "content_copy"; text: "Copy"; onClicked: u.copy(u.report()) }
            SmallBtn { icon: "photo_camera"; text: "Snapshot"; onClicked: u.snapshot() }
            SmallBtn { visible: !u.wide; icon: "history"; on: u.showHistory; onClicked: u.showHistory = !u.showHistory }
        }
        ColumnLayout {
            visible: !(u.showHistory && !u.wide)
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10
            // the rings: a fixed size, spread evenly
            RowLayout {
                Layout.fillWidth: true
                Repeater {
                    model: [[Stats.cpu, Math.round(Stats.cpu * 100) + "%", "CPU"], [Stats.mem, Math.round(Stats.mem * 100) + "%", "Memory"],
                            [Stats.gpu, Math.round(Stats.gpu * 100) + "%", "GPU"], [Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°", "CPU temp"]]
                    Item {
                        id: ringCell
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: rg.height
                        Ring {
                            id: rg
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.max(60, Math.min(110, ringCell.width - 4)); height: width
                            thickness: 8
                            value: ringCell.modelData[0]; text: ringCell.modelData[1]; caption: ringCell.modelData[2]
                        }
                    }
                }
            }
            // the numbers (click one to copy it)
            GridLayout {
                Layout.fillWidth: true
                columns: u.width > 560 ? 2 : 1
                rowSpacing: 2; columnSpacing: 10
                Repeater {
                    model: u.facts
                    Pressable {
                        id: nr
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        color: hovered ? Theme.containerHigh : "transparent"
                        onClicked: u.copy(modelData[1] + ": " + modelData[2])
                        Icon { x: 6; anchors.verticalCenter: parent.verticalCenter; name: nr.modelData[0]; size: 16; color: Theme.subtext }
                        Label { x: 28; anchors.verticalCenter: parent.verticalCenter; text: nr.modelData[1]; muted: true; font.pixelSize: Theme.sizeSmall }
                        Label { anchors.right: parent.right; anchors.rightMargin: 8; anchors.verticalCenter: parent.verticalCenter; width: parent.width - 130; horizontalAlignment: Text.AlignRight; elide: Text.ElideLeft; text: nr.modelData[2]; font.pixelSize: Theme.sizeSmall; strong: true }
                    }
                }
            }
            // the last two minutes of one of them
            RowLayout {
                Layout.fillWidth: true
                Label { text: u.graphs[u.graph][1] + " · now " + u.fmtG(u.gv.length ? u.gv[u.gv.length - 1] : 0) + " · avg " + u.fmtG(u.avg) + " · peak " + u.fmtG(u.peak); muted: true; font.pixelSize: Theme.sizeSmall; Layout.fillWidth: true; elide: Text.ElideRight }
                Segmented { width: 220; height: 30; opts: [["cpu", "CPU"], ["mem", "RAM"], ["gpu", "GPU"], ["temp", "Temp"]]; value: u.graph; onPicked: v => u.graph = v }
            }
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: u.wide ? 160 : 72
                radius: Theme.corner(72, 4)
                color: Theme.container
                Spark { anchors.fill: parent; anchors.margins: 8; values: u.gv }
                Label { anchors.left: parent.left; anchors.bottom: parent.bottom; anchors.margins: 6; text: "2 min ago"; muted: true; font.pixelSize: Theme.sizeSmall - 3 }
                Label { anchors.right: parent.right; anchors.bottom: parent.bottom; anchors.margins: 6; text: "now"; muted: true; font.pixelSize: Theme.sizeSmall - 3 }
            }
            // narrow: the programs under it
            ProgramList { visible: !u.wide; Layout.fillWidth: true }
            Item { Layout.fillHeight: true }
        }
        SnapshotList { visible: u.showHistory && !u.wide; Layout.fillWidth: true; Layout.fillHeight: true }
    }

    // ── wide: the programs and the snapshots beside it ──
    ColumnLayout {
        visible: u.wide
        Layout.fillWidth: true
        Layout.fillHeight: true
        Layout.preferredWidth: 2
        spacing: 8
        ProgramList { Layout.fillWidth: true }
        Label { text: "Snapshots"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.topMargin: 6 }
        SnapshotList { Layout.fillWidth: true; Layout.fillHeight: true }
    }

    // what's using the most CPU now (click one to copy it)
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
                u.busiest = Object.values(m).sort((a, b) => b.cpu - a.cpu || b.rss - a.rss).slice(0, u.wide ? 10 : 6);
            }
        }
    }
    Timer { interval: 2500; running: u.visible; repeat: true; triggeredOnStart: true; onTriggered: ps.running = true }
    component ProgramList: ColumnLayout {
        spacing: 2
        Label { text: "Busiest programs"; muted: !u.wide; strong: u.wide; font.pixelSize: u.wide ? Theme.sizeTitle : Theme.sizeSmall }
        Repeater {
            model: u.busiest
            Pressable {
                id: pr
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.preferredHeight: 28
                color: hovered ? Theme.containerHigh : (index % 2 === 0 ? Theme.container : "transparent")
                onClicked: u.copy(modelData.n + " " + (Math.round(modelData.cpu * 10) / 10) + "% CPU, " + Stats.bytes(modelData.rss))
                Label { x: 10; width: parent.width - 170; elide: Text.ElideRight; anchors.verticalCenter: parent.verticalCenter; text: pr.modelData.n; font.pixelSize: Theme.sizeSmall }
                Label { anchors.right: memL.left; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; text: (Math.round(pr.modelData.cpu * 10) / 10) + "%"; strong: true; font.pixelSize: Theme.sizeSmall }
                Label { id: memL; anchors.right: parent.right; anchors.rightMargin: 10; anchors.verticalCenter: parent.verticalCenter; width: 70; horizontalAlignment: Text.AlignRight; text: Stats.bytes(pr.modelData.rss); muted: true; font.pixelSize: Theme.sizeSmall }
            }
        }
    }
    // snapshots kept: when, a line of it, copy, remove
    component SnapshotList: Rectangle {
        radius: Theme.corner(80, 4)
        color: Theme.container
        ListView {
            SmoothWheel {}
            anchors.fill: parent; anchors.margins: 6
            clip: true
            spacing: 2
            model: u.snapshots
            delegate: Pressable {
                id: sr
                required property var modelData
                required property int index
                width: ListView.view.width; height: 44
                color: hovered ? Theme.containerHigh : "transparent"
                onClicked: u.copy(modelData.text)
                Column {
                    x: 10; anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - 80
                    Label { text: Qt.formatDateTime(new Date(sr.modelData.at), "d MMM, HH:mm:ss"); strong: true; font.pixelSize: Theme.sizeSmall }
                    Label { width: parent.width; elide: Text.ElideRight; text: String(sr.modelData.text).split("\n").slice(0, 3).join(" · "); muted: true; font.pixelSize: Theme.sizeSmall - 2 }
                }
                Row {
                    anchors.right: parent.right; anchors.rightMargin: 4; anchors.verticalCenter: parent.verticalCenter
                    CopyBtn { what: sr.modelData.text }
                    Pressable {
                        width: 26; height: 26
                        color: hovered ? Theme.control : "transparent"
                        onClicked: Store.set("quick.usageSnapshots", u.snapshots.filter((x, j) => j !== sr.index))
                        Icon { anchors.centerIn: parent; name: "close"; size: 14; color: Theme.subtext }
                    }
                }
            }
            Label { anchors.centerIn: parent; width: parent.width - 20; horizontalAlignment: Text.AlignHCenter; wrapMode: Text.WordWrap; visible: u.snapshots.length === 0; text: "Snapshot keeps how the system is doing right now, to look at or copy later"; muted: true; font.pixelSize: Theme.sizeSmall; Balance {} }
        }
    }
}
