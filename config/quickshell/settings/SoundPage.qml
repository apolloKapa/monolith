import QtQuick
import QtQuick.Layouts
import Quickshell.Io

Item {
    id: pg
    property real vol: 0
    property bool muted: false
    property real mic: 0
    property bool micMuted: false
    property var sinks: []
    property string defSink: ""
    property string pendTarget: ""
    property real pendVal: 0

    function parseVol(t, isMic) {
        var m = t.match(/Volume: *([0-9.]+)/)
        var v = m ? parseFloat(m[1]) : 0
        var mu = t.indexOf("MUTED") >= 0
        if (isMic) { mic = v; micMuted = mu } else { vol = v; muted = mu }
    }
    function refresh() { rdOut.running = true; rdMic.running = true; rdSinks.running = true; rdDef.running = true }
    function run(cmd) { runner.command = cmd; runner.running = true }
    function setVol(target, v) { pendTarget = target; pendVal = v; if (!tm.running) tm.start() }

    Component.onCompleted: refresh()
    Process { id: rdOut; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SINK@"]; stdout: StdioCollector { onStreamFinished: pg.parseVol(text, false) } }
    Process { id: rdMic; command: ["wpctl", "get-volume", "@DEFAULT_AUDIO_SOURCE@"]; stdout: StdioCollector { onStreamFinished: pg.parseVol(text, true) } }
    Process { id: rdSinks; command: ["pactl", "-f", "json", "list", "sinks"]; stdout: StdioCollector { onStreamFinished: { try { pg.sinks = JSON.parse(text) } catch (e) { pg.sinks = [] } } } }
    Process { id: rdDef; command: ["pactl", "get-default-sink"]; stdout: StdioCollector { onStreamFinished: pg.defSink = text.trim() } }
    Process { id: runner; onExited: pg.refresh() }
    Process { id: setter }
    Timer { id: tm; interval: 100; onTriggered: { setter.command = ["wpctl", "set-volume", pg.pendTarget, pg.pendVal.toFixed(2)]; setter.running = true } }
    Timer { interval: 2500; running: true; repeat: true; onTriggered: { if (!outBar.dragging && !micBar.dragging) pg.refresh() } }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Lbl { text: "OUTPUT VOLUME  " + Math.round(pg.vol * 100) + "%" + (pg.muted ? "  (muted)" : "") }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Bar { id: outBar; Layout.fillWidth: true; value: pg.vol; onMoved: v => { pg.vol = v; pg.setVol("@DEFAULT_AUDIO_SINK@", v) } }
            Btn { label: pg.muted ? "Unmute" : "Mute"; active: pg.muted; onClicked: pg.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SINK@", "toggle"]) }
        }
        Lbl { text: "MICROPHONE  " + Math.round(pg.mic * 100) + "%" + (pg.micMuted ? "  (muted)" : "") }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Bar { id: micBar; Layout.fillWidth: true; value: pg.mic; onMoved: v => { pg.mic = v; pg.setVol("@DEFAULT_AUDIO_SOURCE@", v) } }
            Btn { label: pg.micMuted ? "Unmute" : "Mute"; active: pg.micMuted; onClicked: pg.run(["wpctl", "set-mute", "@DEFAULT_AUDIO_SOURCE@", "toggle"]) }
        }
        Lbl { text: "OUTPUT DEVICE" }
        Lbl { visible: pg.sinks.length === 0; text: "No devices found (needs pactl, from libpulse)" }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: pg.sinks
            delegate: Rectangle {
                required property var modelData
                property bool isDef: modelData.name === pg.defSink
                width: ListView.view.width
                height: 34
                color: isDef ? "#ffffff" : (ma.containsMouse ? "#2a2a2a" : "#111111")
                Text { anchors.verticalCenter: parent.verticalCenter; x: 10; width: parent.width - 20; elide: Text.ElideRight; text: modelData.description; color: parent.isDef ? "#000000" : "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 14 }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pg.run(["pactl", "set-default-sink", modelData.name]) }
            }
        }
    }
}
