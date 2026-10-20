import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property var outs: []
    property int sel: 0
    property string status: "Changes apply live. Press Save to keep them after a reload."
    property var cs: outs.length > sel ? outs[sel] : null

    function parse(t) {
        var d
        try { d = JSON.parse(t) } catch (e) { status = "Could not read outputs"; return }
        var names = Object.keys(d).sort()
        var list = []
        for (var k = 0; k < names.length; k++) {
            var out = d[names[k]]
            var lg = out.logical
            var modes = []
            for (var i = 0; i < out.modes.length; i++) {
                var m = out.modes[i]
                modes.push({
                    label: m.width + "x" + m.height + "  @  " + (m.refresh_rate / 1000).toFixed(2) + " Hz",
                    arg: m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3),
                    cur: i === out.current_mode
                })
            }
            list.push({
                name: names[k],
                enabled: !!lg,
                modes: modes,
                tf: lg ? String(lg.transform).replace(/^_/, "").toLowerCase() : "normal",
                info: ((out.make || "") + " " + (out.model || "")).trim()
            })
        }
        outs = list
        if (sel >= list.length) sel = 0
    }
    function run(cmd) { runner.command = cmd; runner.running = true }
    function enabledCount() {
        var n = 0
        for (var i = 0; i < outs.length; i++) if (outs[i].enabled) n++
        return n
    }

    Component.onCompleted: lister.running = true
    Process {
        id: lister
        command: ["niri", "msg", "-j", "outputs"]
        stdout: StdioCollector { onStreamFinished: pg.parse(text) }
    }
    Process { id: runner; onExited: lister.running = true }
    Process {
        id: saver
        command: [Quickshell.env("HOME") + "/.local/bin/displaysave"]
        stdout: StdioCollector { onStreamFinished: pg.status = text.trim() }
    }

    RowLayout {
        anchors.fill: parent
        spacing: 18

        ColumnLayout {
            Layout.preferredWidth: 190
            Layout.fillHeight: true
            spacing: 8
            Lbl { text: "OUTPUTS" }
            Repeater {
                model: pg.outs
                delegate: Rectangle {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 54
                    color: pg.sel === index ? "#ffffff" : "#111111"
                    border.color: "#555555"
                    border.width: 1
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        x: 10
                        spacing: 2
                        Text { text: modelData.name; color: pg.sel === index ? "#000000" : "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 15; font.bold: true }
                        Text { text: modelData.enabled ? "on" : "off"; color: pg.sel === index ? "#333333" : "#a0a0a0"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                    }
                    MouseArea { anchors.fill: parent; onClicked: pg.sel = index }
                }
            }
            Item { Layout.fillHeight: true }
        }

        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 10

            Text {
                text: pg.cs ? pg.cs.name + "   " + pg.cs.info : "no outputs found"
                color: "#ffffff"
                font.family: "JetBrains Mono"
                font.pixelSize: 16
                font.bold: true
            }
            Btn {
                label: pg.cs && pg.cs.enabled ? "Monitor: ON  (click to disable)" : "Monitor: OFF  (click to enable)"
                active: pg.cs ? pg.cs.enabled : false
                onClicked: {
                    if (!pg.cs) return
                    if (pg.cs.enabled && pg.enabledCount() <= 1) { pg.status = "Cannot disable the last active monitor"; return }
                    pg.run(["sh", "-c", "niri msg output " + pg.cs.name + (pg.cs.enabled ? " off" : " on; sleep 1; wshome")])
                }
            }
            Lbl { text: "ROTATION" }
            Row {
                spacing: 8
                Repeater {
                    model: [ { l: "0", a: "normal" }, { l: "90", a: "90" }, { l: "180", a: "180" }, { l: "270", a: "270" } ]
                    delegate: Btn {
                        required property var modelData
                        label: modelData.l
                        active: pg.cs ? pg.cs.tf === modelData.a : false
                        onClicked: if (pg.cs) pg.run(["niri", "msg", "output", pg.cs.name, "transform", modelData.a])
                    }
                }
            }
            Lbl { text: "RESOLUTION AND REFRESH RATE" }
            ListView {
                Layout.fillWidth: true
                Layout.fillHeight: true
                clip: true
                spacing: 2
                model: pg.cs ? pg.cs.modes : []
                delegate: Rectangle {
                    required property var modelData
                    width: ListView.view.width
                    height: 30
                    color: modelData.cur ? "#ffffff" : (ma.containsMouse ? "#2a2a2a" : "#111111")
                    Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: modelData.label; color: modelData.cur ? "#000000" : "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 14 }
                    MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: if (pg.cs) pg.run(["niri", "msg", "output", pg.cs.name, "mode", modelData.arg]) }
                }
            }
            RowLayout {
                spacing: 8
                Btn { label: "Save to config"; onClicked: { pg.status = "Saving..."; saver.running = true } }
                Btn { label: "Refresh"; onClicked: lister.running = true }
                Btn { label: "Workspaces home"; onClicked: pg.run(["wshome"]) }
            }
            Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
        }
    }
}
