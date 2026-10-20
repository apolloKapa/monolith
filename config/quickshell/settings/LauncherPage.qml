import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property var vals: ({})
    property string status: "Changes apply to the launcher straight away. Press Try it to see them."
    readonly property string theme: Quickshell.env("HOME") + "/.config/quickshell/launcher/Theme.qml"
    readonly property var speedKeys: ["animLine", "animOpen", "animFade", "animFast", "animMove"]

    function parse(t) {
        var out = {}
        var lines = t.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/readonly property (\w+) (\w+): (.*)$/)
            if (m) out[m[2]] = m[3].trim()
        }
        vals = out
    }
    // change several numbers in Theme.qml with ONE sed call
    function setMany(keys, values) {
        if (setter.running) return
        var cmd = ["sed", "-i"]
        for (var i = 0; i < keys.length; i++) {
            cmd.push("-e")
            cmd.push("s|" + keys[i] + ": [0-9]*|" + keys[i] + ": " + values[i] + "|")
        }
        cmd.push(theme)
        setter.command = cmd
        setter.running = true
    }

    Component.onCompleted: rd.running = true
    Process { id: rd; command: ["cat", pg.theme]; stdout: StdioCollector { onStreamFinished: pg.parse(text) } }
    Process { id: setter; onExited: rd.running = true }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        Lbl { text: "ANIMATION SPEED" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    { l: "Instant", v: [0, 0, 0, 0, 0] },
                    { l: "Fast", v: [90, 130, 70, 70, 110] },
                    { l: "Normal", v: [220, 320, 160, 120, 220] },
                    { l: "Slow", v: [350, 450, 250, 160, 300] }
                ]
                delegate: Btn {
                    required property var modelData
                    label: modelData.l
                    active: pg.vals.animLine === String(modelData.v[0])
                    onClicked: pg.setMany(pg.speedKeys, modelData.v)
                }
            }
        }

        Lbl { text: "MENU SIZE" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [ { l: "Small", w: 640, h: 480 }, { l: "Medium", w: 760, h: 580 }, { l: "Large", w: 900, h: 680 } ]
                delegate: Btn {
                    required property var modelData
                    label: modelData.l + "  " + modelData.w + "x" + modelData.h
                    active: pg.vals.menuWidth === String(modelData.w)
                    onClicked: pg.setMany(["menuWidth", "menuHeight"], [modelData.w, modelData.h])
                }
            }
        }

        Lbl { text: "FAVOURITE TILE SIZE" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [ 44, 52, 64 ]
                delegate: Btn {
                    required property int modelData
                    label: modelData + " px"
                    active: pg.vals.favTile === String(modelData)
                    onClicked: pg.setMany(["favTile"], [modelData])
                }
            }
        }

        Lbl { text: "TEST" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn { label: "Try it"; onClicked: Quickshell.execDetached(["qs", "-c", "launcher", "ipc", "call", "launcher", "toggle"]) }
        }

        Item { Layout.fillHeight: true }
        Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
    }
}
