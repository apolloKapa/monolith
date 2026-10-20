import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property var vals: ({})
    property string status: "Changes apply to the bar instantly."
    readonly property string theme: Quickshell.env("HOME") + "/.config/quickshell/bar/Theme.qml"

    function parse(t) {
        var out = {}
        var lines = t.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/readonly property (\w+) (\w+): (.*)$/)
            if (m) out[m[2]] = m[3].trim()
        }
        vals = out
    }
    function on(k) { return vals[k] === "true" }
    function scr() { return (vals.screens || "").replace(/ /g, "") }
    property var queue: []
    function set(k, v) { queue = queue.concat([[k, v]]); if (!setter.running) next() }
    function next() {
        if (queue.length === 0) { rd.running = true; return }
        var job = queue[0]
        queue = queue.slice(1)
        setter.command = [Quickshell.env("HOME") + "/.local/bin/bartheme", job[0], job[1]]
        setter.running = true
    }

    Component.onCompleted: rd.running = true
    Process { id: rd; command: ["cat", pg.theme]; stdout: StdioCollector { onStreamFinished: pg.parse(text) } }
    Process {
        id: setter
        stdout: StdioCollector { onStreamFinished: if (text.trim()) pg.status = text.trim() }
        onExited: pg.next()
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Lbl { text: "MODULES" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [ { l: "Workspaces", k: "showWorkspaces" }, { l: "Stats", k: "showStats" }, { l: "Clock", k: "showClock" }, { l: "Tray", k: "showTray" }, { l: "Power", k: "showPower" } ]
                delegate: Btn {
                    required property var modelData
                    label: modelData.l + ": " + (pg.on(modelData.k) ? "ON" : "OFF")
                    active: pg.on(modelData.k)
                    onClicked: pg.set(modelData.k, pg.on(modelData.k) ? "false" : "true")
                }
            }
        }

        Lbl { text: "SHOW THE BAR ON" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [ { l: "DP-1", v: "[\"DP-1\"]" }, { l: "DP-2", v: "[\"DP-2\"]" }, { l: "Both", v: "[\"DP-1\",\"DP-2\"]" }, { l: "Hidden", v: "[\"none\"]" } ]
                delegate: Btn {
                    required property var modelData
                    label: modelData.l
                    active: pg.scr() === modelData.v
                    onClicked: pg.set("screens", modelData.v)
                }
            }
        }

        Lbl { text: "BAR HEIGHT" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [ 32, 36, 40, 48, 56 ]
                delegate: Btn {
                    required property int modelData
                    label: modelData + " px"
                    active: pg.vals.barHeight === String(modelData)
                    onClicked: pg.set("barHeight", String(modelData))
                }
            }
        }

        Lbl { text: "TRAY ICON SIZE" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [ 18, 22, 26, 30 ]
                delegate: Btn {
                    required property int modelData
                    label: modelData + " px"
                    active: pg.vals.trayIcon === String(modelData)
                    onClicked: pg.set("trayIcon", String(modelData))
                }
            }
        }

        Lbl { text: "ANIMATIONS" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn { label: "On"; active: pg.vals.animNormal !== "0"; onClicked: { pg.set("animFast", "120"); pg.set("animNormal", "220"); pg.set("animSlow", "450") } }
            Btn { label: "Off"; active: pg.vals.animNormal === "0"; onClicked: { pg.set("animFast", "0"); pg.set("animNormal", "0"); pg.set("animSlow", "0") } }
        }

        Item { Layout.fillHeight: true }
        Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
    }
}
