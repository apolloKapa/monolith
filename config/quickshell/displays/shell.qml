import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

ShellRoot {
    id: root
    property var outs: []
    property int sel: 0
    property string status: "Changes apply live. Press Save to keep them after a reload or reboot."
    readonly property string home: Quickshell.env("HOME")

    function parse(t) {
        var d
        try { d = JSON.parse(t) } catch (e) { status = "Could not read outputs"; return }
        var names = Object.keys(d).sort()
        var list = []
        for (var k = 0; k < names.length; k++) {
            var o = d[names[k]]
            var lg = o.logical
            var modes = []
            for (var i = 0; i < o.modes.length; i++) {
                var m = o.modes[i]
                modes.push({
                    label: m.width + "x" + m.height + "  @  " + (m.refresh_rate / 1000).toFixed(2) + " Hz",
                    arg: m.width + "x" + m.height + "@" + (m.refresh_rate / 1000).toFixed(3),
                    cur: i === o.current_mode
                })
            }
            list.push({
                name: names[k],
                enabled: !!lg,
                modes: modes,
                tf: lg ? String(lg.transform).replace(/^_/, "").toLowerCase() : "normal",
                info: ((o.make || "") + " " + (o.model || "")).trim()
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
        stdout: StdioCollector { onStreamFinished: root.parse(text) }
    }
    Process { id: runner; onExited: lister.running = true }
    Process {
        id: saver
        command: [root.home + "/.local/bin/displaysave"]
        stdout: StdioCollector { onStreamFinished: root.status = text.trim() }
    }

    component Btn: Rectangle {
        id: b
        property string label: ""
        property bool active: false
        signal clicked()
        implicitWidth: t.implicitWidth + 24
        implicitHeight: 34
        color: active ? "#ffffff" : (m.containsMouse ? "#2a2a2a" : "#111111")
        border.color: "#ffffff"
        border.width: 1
        Text {
            id: t
            anchors.centerIn: parent
            text: b.label
            color: b.active ? "#000000" : "#ffffff"
            font.family: "JetBrains Mono"
            font.pixelSize: 14
        }
        MouseArea { id: m; anchors.fill: parent; hoverEnabled: true; onClicked: b.clicked() }
    }

    FloatingWindow {
        title: "Displays"
        implicitWidth: 800
        implicitHeight: 560
        color: "#1a1a1a"

        Rectangle { anchors.fill: parent; color: "#1a1a1a"; border.color: "#ffffff"; border.width: 2 }

        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18

            ColumnLayout {
                Layout.preferredWidth: 210
                Layout.fillHeight: true
                spacing: 8
                Text { text: "OUTPUTS"; color: "#a0a0a0"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                Repeater {
                    model: root.outs
                    delegate: Rectangle {
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 54
                        color: root.sel === index ? "#ffffff" : "#111111"
                        border.color: "#555555"
                        border.width: 1
                        Column {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            spacing: 2
                            Text {
                                text: modelData.name
                                color: root.sel === index ? "#000000" : "#ffffff"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 15
                                font.bold: true
                            }
                            Text {
                                text: modelData.enabled ? "on" : "off"
                                color: root.sel === index ? "#333333" : "#a0a0a0"
                                font.family: "JetBrains Mono"
                                font.pixelSize: 12
                            }
                        }
                        MouseArea { anchors.fill: parent; onClicked: root.sel = index }
                    }
                }
                Item { Layout.fillHeight: true }
            }

            ColumnLayout {
                id: panel
                property var o: root.outs.length > root.sel ? root.outs[root.sel] : null
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 10

                Text {
                    text: panel.o ? panel.o.name + "   " + panel.o.info : "no outputs found"
                    color: "#ffffff"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 16
                    font.bold: true
                }

                Btn {
                    label: panel.o && panel.o.enabled ? "Monitor: ON  (click to disable)" : "Monitor: OFF  (click to enable)"
                    active: panel.o ? panel.o.enabled : false
                    onClicked: {
                        if (!panel.o) return
                        if (panel.o.enabled && root.enabledCount() <= 1) {
                            root.status = "Cannot disable the last active monitor"
                            return
                        }
                        root.run(["niri", "msg", "output", panel.o.name, panel.o.enabled ? "off" : "on"])
                    }
                }

                Text { text: "ROTATION"; color: "#a0a0a0"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                Row {
                    spacing: 8
                    Repeater {
                        model: [ { l: "0", a: "normal" }, { l: "90", a: "90" }, { l: "180", a: "180" }, { l: "270", a: "270" } ]
                        delegate: Btn {
                            required property var modelData
                            label: modelData.l
                            active: panel.o ? panel.o.tf === modelData.a : false
                            onClicked: if (panel.o) root.run(["niri", "msg", "output", panel.o.name, "transform", modelData.a])
                        }
                    }
                }

                Text { text: "RESOLUTION AND REFRESH RATE"; color: "#a0a0a0"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                ListView {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    clip: true
                    spacing: 2
                    model: panel.o ? panel.o.modes : []
                    delegate: Rectangle {
                        required property var modelData
                        width: ListView.view.width
                        height: 30
                        color: modelData.cur ? "#ffffff" : (ma.containsMouse ? "#2a2a2a" : "#111111")
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            x: 10
                            text: modelData.label
                            color: modelData.cur ? "#000000" : "#ffffff"
                            font.family: "JetBrains Mono"
                            font.pixelSize: 14
                        }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: if (panel.o) root.run(["niri", "msg", "output", panel.o.name, "mode", modelData.arg])
                        }
                    }
                }

                RowLayout {
                    spacing: 8
                    Btn { label: "Save to config"; onClicked: { root.status = "Saving..."; saver.running = true } }
                    Btn { label: "Refresh"; onClicked: lister.running = true }
                }
                Text {
                    Layout.fillWidth: true
                    text: root.status
                    color: "#a0a0a0"
                    wrapMode: Text.WordWrap
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                }
            }
        }
    }
}
