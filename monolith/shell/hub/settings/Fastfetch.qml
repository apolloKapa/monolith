import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// Fastfetch: your presets (~/.config/monolith/fastfetch), each with a live preview in the
// shell's colours. Use one, edit it in a terminal, copy, delete, or start a new one.
ColumnLayout {
    id: sec
    spacing: 8
    readonly property string script: Qt.resolvedUrl("../../scripts/fastfetch.py").toString().replace("file://", "")
    property var list: []
    property bool loaded: false
    function load() { lister.running = true; }
    Component.onCompleted: load()
    Process { id: lister; command: ["python3", sec.script, "list"]; stdout: StdioCollector { onStreamFinished: { try { sec.list = JSON.parse(text); } catch (e) {} sec.loaded = true; } } }
    Process { id: act; onExited: sec.load() }
    function run(args) { act.command = ["python3", sec.script].concat(args); act.running = true; }
    function edit(name) {
        HubState.close();
        Quickshell.execDetached(["sh", "-c", Prefs.terminal + " sh -c '${EDITOR:-nano} \"$1\"' _ \"$1\"", "_", Quickshell.env("HOME") + "/.config/monolith/fastfetch/" + name + ".jsonc"]);
    }

    SettingRow {
        icon: "terminal"; title: "Fastfetch"; desc: "What a new terminal greets you with. Colours follow the wallpaper; {{primary}} and the like in a preset become them"
        Row {
            spacing: 6
            Button { text: "New"; icon: "add"; onClicked: sec.run(["new"]) }
            Button { text: "Reload"; icon: "refresh"; onClicked: sec.load() }
        }
    }
    Label { visible: sec.list.length === 0; text: sec.loaded ? "No presets yet" : "Loading the previews…"; muted: true; Layout.leftMargin: 6 }
    Repeater {
        model: sec.list
        Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: head.height + pv.height + 30
            radius: Theme.corner(80, 6)
            color: modelData.active ? Theme.accentContainer : Theme.container
            border.width: modelData.active ? 2 : 0
            border.color: Theme.accent
            RowLayout {
                id: head
                x: 14; y: 10
                width: parent.width - 28
                height: 40
                Label { text: modelData.name; strong: true; font.pixelSize: Theme.sizeTitle; color: modelData.active ? Theme.onAccentContainer : Theme.text; Layout.fillWidth: true }
                Button { visible: !modelData.active; text: "Use"; primary: true; onClicked: sec.run(["apply", modelData.name]) }
                Button { text: "Edit"; icon: "edit"; onClicked: sec.edit(modelData.name) }
                Button { text: "Copy"; icon: "content_copy"; onClicked: sec.run(["duplicate", modelData.name]) }
                Button {
                    id: del
                    visible: !modelData.active
                    property bool armed: false
                    text: armed ? "Sure?" : "Delete"
                    onClicked: { if (armed) sec.run(["delete", modelData.name]); else { armed = true; disarm.restart(); } }
                    Timer { id: disarm; interval: 4000; onTriggered: del.armed = false }
                }
            }
            // the preview: fastfetch's output, coloured, on a terminal-like tile
            Rectangle {
                id: pv
                x: 14; y: head.y + head.height + 8
                width: parent.width - 28
                height: Math.min(360, out.implicitHeight + 24)
                radius: Theme.corner(60, 2)
                color: Theme.m("surface_container_lowest", "#0d0e13")
                clip: true
                Text {
                    id: out
                    x: 12; y: 12
                    textFormat: Text.RichText
                    text: modelData.html
                    color: Theme.text
                    font.family: "monospace"
                    font.pixelSize: 11
                }
            }
        }
    }
}
