import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property var presets: ({})
    property var names: []
    property string cur: "Mono"
    property string mode: "preset"
    property string status: "Pick a theme. It recolours the bar, window borders, rofi, the lock screen, notifications and this window."
    readonly property string bin: Quickshell.env("HOME") + "/.local/bin/applytheme"

    function reload() { rdState.running = true }
    function apply(arg) { status = "Applying..."; runner.command = [bin, arg]; runner.running = true }

    Component.onCompleted: { rdList.running = true; rdState.running = true }
    Process {
        id: rdList
        command: [pg.bin, "list"]
        stdout: StdioCollector { onStreamFinished: { try { var d = JSON.parse(text); pg.presets = d; pg.names = Object.keys(d) } catch (e) { pg.status = "Could not read the theme list" } } }
    }
    Process {
        id: rdState
        command: ["cat", Quickshell.env("HOME") + "/.config/theme/state.json"]
        stdout: StdioCollector { onStreamFinished: { try { var s = JSON.parse(text); pg.cur = s.name; pg.mode = s.mode } catch (e) { pg.cur = "Mono"; pg.mode = "preset" } } }
    }
    Process {
        id: runner
        stdout: StdioCollector { onStreamFinished: { if (text.trim()) pg.status = text.trim(); pg.reload() } }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Lbl { text: "CURRENT:  " + pg.cur + (pg.mode === "wallpaper" ? "  (follows the wallpaper)" : "") }
        Lbl { text: "PRESETS" }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: pg.names
                delegate: Rectangle {
                    id: card
                    required property string modelData
                    property var p: pg.presets[modelData]
                    property bool sel: pg.mode === "preset" && pg.cur === modelData
                    width: 150
                    height: 72
                    color: p.bg
                    border.width: sel ? 3 : 1
                    border.color: sel ? p.accent : p.border
                    Row {
                        x: 10
                        y: 10
                        spacing: 6
                        Repeater {
                            model: [card.p.accent, card.p.fg, card.p.border, card.p.hover]
                            delegate: Rectangle { required property string modelData; width: 18; height: 18; color: modelData }
                        }
                    }
                    Text {
                        x: 10
                        anchors.bottom: parent.bottom
                        anchors.bottomMargin: 10
                        text: card.modelData
                        color: card.p.fg
                        font.family: "JetBrains Mono"
                        font.pixelSize: 14
                        font.bold: true
                    }
                    MouseArea { anchors.fill: parent; onClicked: pg.apply(card.modelData) }
                }
            }
        }
        Lbl { text: "WALLPAPER COLOURS" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn { label: pg.mode === "wallpaper" ? "Following wallpaper: ON" : "Match my wallpaper"; active: pg.mode === "wallpaper"; onClicked: pg.apply("wallpaper") }
        }
        Lbl { Layout.fillWidth: true; wrapMode: Text.WordWrap; text: "Uses the dominant colour of the current wallpaper. While it is on, a new wallpaper recolours everything within a few seconds. Pick a preset to turn it off." }
        Item { Layout.fillHeight: true }
        Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
    }
}
