import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property var nets: []
    property bool wifiOn: true
    property string status: "Saved networks only. Use the network editor to add new ones."

    function split(l) {
        var out = []
        var cur = ""
        var bs = String.fromCharCode(92)
        for (var i = 0; i < l.length; i++) {
            var c = l.charAt(i)
            if (c === bs && i + 1 < l.length) { i++; cur += l.charAt(i) }
            else if (c === ":") { out.push(cur); cur = "" }
            else cur += c
        }
        out.push(cur)
        return out
    }
    function parse(t) {
        var best = {}
        var lines = t.split("\n")
        for (var i = 0; i < lines.length; i++) {
            if (!lines[i]) continue
            var f = split(lines[i])
            if (f.length < 4 || !f[1]) continue
            var n = { ssid: f[1], sig: parseInt(f[2]) || 0, sec: f[3], act: f[0] === "*" }
            var old = best[n.ssid]
            if (!old || n.act || (!old.act && n.sig > old.sig)) best[n.ssid] = n
        }
        var list = []
        for (var k in best) list.push(best[k])
        list.sort(function(a, b) { return (b.act - a.act) || (b.sig - a.sig) })
        nets = list
    }
    function refresh() { rdRadio.running = true; rdList.running = true }
    function run(cmd) { runner.command = cmd; runner.running = true }

    Component.onCompleted: refresh()
    Process { id: rdRadio; command: ["nmcli", "radio", "wifi"]; stdout: StdioCollector { onStreamFinished: pg.wifiOn = text.trim() === "enabled" } }
    Process { id: rdList; command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]; stdout: StdioCollector { onStreamFinished: pg.parse(text) } }
    Process {
        id: runner
        stdout: StdioCollector { onStreamFinished: if (text.trim()) pg.status = text.trim() }
        stderr: StdioCollector { onStreamFinished: if (text.trim()) pg.status = text.trim() }
        onExited: pg.refresh()
    }
    Timer { interval: 8000; running: true; repeat: true; onTriggered: pg.refresh() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        RowLayout {
            spacing: 8
            Btn { label: pg.wifiOn ? "Wi-Fi: ON" : "Wi-Fi: OFF"; active: pg.wifiOn; onClicked: pg.run(["nmcli", "radio", "wifi", pg.wifiOn ? "off" : "on"]) }
            Btn { label: "Rescan"; onClicked: pg.run(["nmcli", "dev", "wifi", "rescan"]) }
            Btn { label: "Network editor"; onClicked: Quickshell.execDetached(["nm-connection-editor"]) }
        }
        Lbl { text: "WI-FI NETWORKS  (click to connect or disconnect)" }
        Lbl { visible: pg.nets.length === 0; text: "No networks found (no Wi-Fi adapter, or Wi-Fi is off)" }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: pg.nets
            delegate: Rectangle {
                required property var modelData
                width: ListView.view.width
                height: 34
                color: modelData.act ? "#ffffff" : (ma.containsMouse ? "#2a2a2a" : "#111111")
                Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: modelData.ssid; color: modelData.act ? "#000000" : "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 14 }
                Text { anchors.verticalCenter: parent.verticalCenter; anchors.right: parent.right; anchors.rightMargin: 10; text: modelData.sig + "%  " + modelData.sec; color: modelData.act ? "#333333" : "#a0a0a0"; font.family: "JetBrains Mono"; font.pixelSize: 12 }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pg.run(["nmcli", "connection", modelData.act ? "down" : "up", "id", modelData.ssid]) }
            }
        }
        Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
    }
}
