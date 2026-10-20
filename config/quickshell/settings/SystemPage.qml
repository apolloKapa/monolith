import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property string profile: ""
    property string kb: ""

    function refresh() { rdProf.running = true; rdKb.running = true }
    function run(cmd) { runner.command = cmd; runner.running = true }

    Component.onCompleted: refresh()
    Process { id: rdProf; command: ["powerprofilesctl", "get"]; stdout: StdioCollector { onStreamFinished: pg.profile = text.trim() } }
    Process {
        id: rdKb
        command: ["niri", "msg", "-j", "keyboard-layouts"]
        stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(text); pg.kb = d.names[d.current_idx] } catch (e) { pg.kb = "" } } }
    }
    Process { id: runner; onExited: pg.refresh() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 12
        Lbl { text: "POWER PROFILE" }
        Row {
            spacing: 8
            Repeater {
                model: [ { l: "Power saver", a: "power-saver" }, { l: "Balanced", a: "balanced" }, { l: "Performance", a: "performance" } ]
                delegate: Btn {
                    required property var modelData
                    label: modelData.l
                    active: pg.profile === modelData.a
                    onClicked: pg.run(["powerprofilesctl", "set", modelData.a])
                }
            }
        }
        Lbl { text: "KEYBOARD LAYOUT" }
        Btn { label: "Switch layout  (now: " + (pg.kb || "unknown") + ")"; onClicked: pg.run(["niri", "msg", "action", "switch-layout", "next"]) }
        Lbl { text: "SHORTCUTS" }
        Row {
            spacing: 8
            Btn { label: "Pick wallpaper"; onClicked: Quickshell.execDetached(["setwall", "pick"]) }
            Btn { label: "Reload niri config"; onClicked: pg.run(["niri", "msg", "action", "load-config-file"]) }
            Btn { label: "Lock screen"; onClicked: Quickshell.execDetached(["swaylock"]) }
        }
        Item { Layout.fillHeight: true }
    }
}
