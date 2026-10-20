import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: pg
    property bool hasCtl: true
    property bool powered: false
    property bool scanning: scanner.running
    property var devs: []
    property var conn: ({})
    property var paired: ({})
    property string status: "Click a device to connect or disconnect. Scan to find new ones."

    // strip terminal colour codes from bluetoothctl output
    function clean(t) {
        var esc = String.fromCharCode(27), out = "", skip = false
        for (var i = 0; i < t.length; i++) {
            var c = t.charAt(i)
            if (c === esc) { skip = true; continue }
            if (skip) { if (c === "m") skip = false; continue }
            out += c
        }
        return out
    }
    function lastLine(t) {
        var l = clean(t).split("\n").filter(x => x.trim() !== "")
        return l.length ? l[l.length - 1].trim() : ""
    }
    function macs(t) {
        var c = {}
        var lines = t.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^Device ([0-9A-Fa-f:]+) /)
            if (m) c[m[1]] = true
        }
        return c
    }
    function parseDevs(t) {
        var list = []
        var lines = t.split("\n")
        for (var i = 0; i < lines.length; i++) {
            var m = lines[i].match(/^Device ([0-9A-Fa-f:]+) (.*)$/)
            if (m) list.push({ mac: m[1], name: m[2] })
        }
        devs = list
    }
    function refresh() { rdPow.running = true; rdDevs.running = true; rdConn.running = true; rdPair.running = true }
    function sh(script) {
        if (runner.running) { status = "Busy, try again in a moment"; return }
        status = "Working..."
        runner.command = ["sh", "-c", script]
        runner.running = true
    }
    function click(d) {
        if (conn[d.mac]) sh("bluetoothctl disconnect " + d.mac)
        else if (paired[d.mac]) sh("bluetoothctl connect " + d.mac)
        else sh("bluetoothctl pair " + d.mac + "; bluetoothctl trust " + d.mac + "; bluetoothctl connect " + d.mac)
    }

    Component.onCompleted: refresh()
    Process {
        id: rdPow
        command: ["bluetoothctl", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                pg.hasCtl = text.indexOf("Controller") >= 0
                pg.powered = text.indexOf("Powered: yes") >= 0
            }
        }
    }
    Process { id: rdDevs; command: ["bluetoothctl", "devices"]; stdout: StdioCollector { onStreamFinished: pg.parseDevs(text) } }
    Process { id: rdConn; command: ["bluetoothctl", "devices", "Connected"]; stdout: StdioCollector { onStreamFinished: pg.conn = pg.macs(text) } }
    Process { id: rdPair; command: ["bluetoothctl", "devices", "Paired"]; stdout: StdioCollector { onStreamFinished: pg.paired = pg.macs(text) } }
    Process {
        id: runner
        stdout: StdioCollector { onStreamFinished: { var l = pg.lastLine(text); if (l !== "") pg.status = l } }
        stderr: StdioCollector { onStreamFinished: { var l = pg.lastLine(text); if (l !== "") pg.status = l } }
        onExited: pg.refresh()
    }
    Process {
        id: scanner
        command: ["bluetoothctl", "--timeout", "8", "scan", "on"]
        onRunningChanged: if (!running) pg.refresh()
    }
    Timer { interval: 6000; running: true; repeat: true; onTriggered: pg.refresh() }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10

        RowLayout {
            spacing: 8
            Btn {
                label: pg.powered ? "Bluetooth: ON" : "Bluetooth: OFF"
                active: pg.powered
                onClicked: pg.sh(pg.powered ? "bluetoothctl power off" : "rfkill unblock bluetooth; sleep 1; bluetoothctl power on; sleep 2; bluetoothctl show | grep -q Powered:.yes || bluetoothctl power on")
            }
            Btn {
                label: pg.scanning ? "Scanning..." : "Scan for devices"
                active: pg.scanning
                onClicked: { if (!scanner.running) { if (pg.powered) scanner.running = true; else pg.status = "Turn Bluetooth on first" } }
            }
            Btn { label: "Refresh"; onClicked: pg.refresh() }
        }

        Lbl {
            visible: !pg.hasCtl
            Layout.fillWidth: true
            wrapMode: Text.WordWrap
            text: "No Bluetooth controller found. The Bluetooth service is probably not running, or the adapter is missing."
        }
        Btn {
            visible: !pg.hasCtl
            label: "Start Bluetooth service"
            onClicked: pg.sh("pkexec systemctl enable --now bluetooth")
        }

        Lbl { text: "DEVICES" }
        Lbl { visible: pg.devs.length === 0; text: "No devices yet. Turn Bluetooth on and press Scan." }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: pg.devs
            delegate: Rectangle {
                required property var modelData
                property bool on: pg.conn[modelData.mac] === true
                property bool known: pg.paired[modelData.mac] === true
                width: ListView.view.width
                height: 34
                color: on ? "#ffffff" : (ma.containsMouse ? "#2a2a2a" : "#111111")
                Behavior on color { ColorAnimation { duration: 120 } }
                Text { anchors.verticalCenter: parent.verticalCenter; x: 10; text: modelData.name; color: parent.on ? "#000000" : "#ffffff"; font.family: "JetBrains Mono"; font.pixelSize: 14 }
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    text: parent.on ? "connected" : (parent.known ? "paired" : "new - click to pair")
                    color: parent.on ? "#333333" : "#a0a0a0"
                    font.family: "JetBrains Mono"
                    font.pixelSize: 12
                }
                MouseArea { id: ma; anchors.fill: parent; hoverEnabled: true; onClicked: pg.click(modelData) }
            }
        }
        Lbl { Layout.fillWidth: true; text: pg.status; wrapMode: Text.WordWrap }
    }
}
