import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../core"
import "../ui"

// Network: the wired connection, Wi-Fi networks (connect, with a password when needed;
// right-click forgets) and Bluetooth devices (connect, pair).
Page {
    id: page
    pageId: "network"
    implicitHeight: Math.min(600, col.implicitHeight)
    property string tab: "wifi"

    property var devices: []          // nmcli devices
    property var networks: []         // Wi-Fi networks in range
    property bool wifiOn: false
    property string askFor: ""        // the network asking for a password
    property string busy: ""

    readonly property var ethernet: devices.filter(d => d.type === "ethernet")
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property var btDevices: Bluetooth.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))

    function refresh() { devProc.running = true; radioProc.running = true; wifiProc.running = true; }
    onCurrentChanged: if (current) refresh()
    Timer { interval: 5000; repeat: true; running: page.current && HubState.open; onTriggered: page.refresh() }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"]
        stdout: StdioCollector { onStreamFinished: page.devices = text.trim().split("\n").filter(l => l).map(l => { const p = l.split(":"); return { name: p[0], type: p[1], state: p[2], conn: p.slice(3).join(":") }; }) }
    }
    Process { id: radioProc; command: ["nmcli", "-t", "radio", "wifi"]; stdout: StdioCollector { onStreamFinished: page.wifiOn = text.trim() === "enabled" } }
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                page.networks = text.trim().split("\n").filter(l => l).map(l => {
                    const p = l.replace(/\\:/g, "\u0001").split(":").map(s => s.replace(/\u0001/g, ":"));
                    return { active: p[0] === "*", ssid: p[1], signal: parseInt(p[2]) || 0, secure: (p[3] || "") !== "" && p[3] !== "--" };
                }).filter(n => n.ssid !== "" && !seen[n.ssid] && (seen[n.ssid] = true)).sort((a, b) => (b.active - a.active) || (b.signal - a.signal));
            }
        }
    }
    Process {
        id: connectProc
        property string ssid: ""
        onExited: code => { page.busy = ""; if (code !== 0) page.askFor = ssid; else page.askFor = ""; page.refresh(); }
    }
    function connect(n, password) {
        busy = n.ssid;
        connectProc.ssid = n.ssid;
        connectProc.command = password ? ["nmcli", "dev", "wifi", "connect", n.ssid, "password", password] : ["nmcli", "dev", "wifi", "connect", n.ssid];
        connectProc.running = true;
    }

    component Seg: Rectangle {
        id: seg
        property var opts: []
        property string value: ""
        signal picked(string v)
        Layout.fillWidth: true
        Layout.preferredHeight: 44
        radius: Theme.corner(height)
        color: Theme.container
        Rectangle {
            y: 4
            x: 4 + seg.opts.findIndex(o => o[0] === seg.value) * ((seg.width - 8) / seg.opts.length)
            width: (seg.width - 8) / seg.opts.length
            height: seg.height - 8
            radius: Theme.corner(height)
            color: Theme.selected
            Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        }
        Row {
            anchors.fill: parent
            anchors.margins: 4
            Repeater {
                model: seg.opts
                Pressable {
                    required property var modelData
                    width: parent.width / seg.opts.length
                    height: parent.height
                    color: "transparent"
                    onClicked: seg.picked(modelData[0])
                    Row {
                        anchors.centerIn: parent
                        spacing: 6
                        Icon { name: modelData[2]; size: 18; filled: seg.value === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: modelData[1]; strong: seg.value === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }
        }
    }

    component Row2: Pressable {
        id: r
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        property string trailing: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 56
        radius: Theme.corner(height)
        color: on ? Theme.selected : Theme.containerHigh
        Bubble { id: rb; x: 10; anchors.verticalCenter: parent.verticalCenter; size: 36; icon: r.icon; on: r.on }
        Column {
            anchors.left: rb.right; anchors.leftMargin: 12
            anchors.right: tr.left; anchors.rightMargin: 8
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; text: r.title; strong: true }
            Label { width: parent.width; text: r.sub; muted: true; font.pixelSize: Theme.sizeSmall; visible: text !== "" }
        }
        Icon { id: tr; anchors.right: parent.right; anchors.rightMargin: 14; anchors.verticalCenter: parent.verticalCenter; name: r.trailing; size: 18; color: Theme.subtext; visible: r.trailing !== "" }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        Seg {
            opts: [["wifi", "Wi-Fi", "wifi"], ["wired", "Ethernet", "lan"], ["bt", "Bluetooth", "bluetooth"]]
            value: page.tab
            onPicked: v => page.tab = v
        }

        // ── Wi-Fi ──
        Row2 {
            visible: page.tab === "wifi"
            icon: page.wifiOn ? "wifi" : "wifi_off"
            title: "Wi-Fi"
            sub: page.wifiOn ? (page.networks.length + " networks") : "Off"
            on: page.wifiOn
            trailing: page.wifiOn ? "toggle_on" : "toggle_off"
            onClicked: { page.wifiOn = !page.wifiOn; Quickshell.execDetached(["nmcli", "radio", "wifi", page.wifiOn ? "on" : "off"]); }
        }
        Repeater {
            model: page.tab === "wifi" && page.wifiOn ? page.networks : []
            ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 6
                Row2 {
                    icon: modelData.signal > 70 ? "signal_wifi_4_bar" : (modelData.signal > 40 ? "network_wifi_3_bar" : "network_wifi_1_bar")
                    title: modelData.ssid
                    sub: page.busy === modelData.ssid ? "Connecting…" : (modelData.active ? "Connected" : (modelData.secure ? "Secured" : "Open"))
                    on: modelData.active
                    trailing: modelData.secure ? "lock" : ""
                    onClicked: {
                        if (modelData.active) Quickshell.execDetached(["nmcli", "connection", "down", "id", modelData.ssid]);
                        else page.connect(modelData, "");
                    }
                    onRightClicked: Quickshell.execDetached(["nmcli", "connection", "delete", "id", modelData.ssid])
                }
                // the password, asked for in place when the network needs one
                Rectangle {
                    visible: page.askFor === modelData.ssid
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    radius: Theme.corner(height)
                    color: Theme.container
                    TextInput {
                        id: pw
                        anchors.fill: parent
                        anchors.leftMargin: 16
                        anchors.rightMargin: 16
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: TextInput.Password
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeBody
                        onVisibleChanged: if (visible) forceActiveFocus()
                        onAccepted: { page.connect(modelData, text); text = ""; }
                        Label { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: pw.text === ""; text: "Password for " + modelData.ssid; muted: true }
                    }
                }
            }
        }

        // ── Ethernet ──
        Repeater {
            model: page.tab === "wired" ? page.ethernet : []
            Row2 {
                required property var modelData
                icon: "lan"
                title: modelData.conn !== "" ? modelData.conn : modelData.name
                sub: modelData.name + " · " + modelData.state
                on: modelData.state === "connected"
                onClicked: Quickshell.execDetached(["nmcli", "dev", modelData.state === "connected" ? "disconnect" : "connect", modelData.name])
            }
        }
        Label {
            visible: page.tab === "wired" && page.ethernet.length === 0
            Layout.fillWidth: true; horizontalAlignment: Text.AlignHCenter
            text: "No wired adapters"; muted: true
        }

        // ── Bluetooth ──
        Row2 {
            visible: page.tab === "bt"
            icon: page.adapter && page.adapter.enabled ? "bluetooth" : "bluetooth_disabled"
            title: "Bluetooth"
            sub: !page.adapter ? "No adapter" : (page.adapter.enabled ? (page.adapter.discovering ? "Looking for devices…" : "On") : "Off")
            on: !!(page.adapter && page.adapter.enabled)
            trailing: page.adapter && page.adapter.enabled ? "toggle_on" : "toggle_off"
            onClicked: if (page.adapter) page.adapter.enabled = !page.adapter.enabled
            onRightClicked: if (page.adapter && page.adapter.enabled) page.adapter.discovering = !page.adapter.discovering
        }
        Repeater {
            model: page.tab === "bt" && page.adapter && page.adapter.enabled ? page.btDevices : []
            Row2 {
                required property var modelData
                icon: modelData.icon && modelData.icon.indexOf("audio") !== -1 ? "headphones" : (modelData.icon && modelData.icon.indexOf("input") !== -1 ? "mouse" : "devices")
                title: modelData.name || modelData.address
                sub: modelData.connected ? ("Connected" + (modelData.batteryAvailable ? " · " + Math.round(modelData.battery * 100) + "%" : "")) : (modelData.paired ? "Paired" : "Click to pair")
                on: modelData.connected
                onClicked: {
                    if (modelData.connected) modelData.disconnect();
                    else if (modelData.paired) modelData.connect();
                    else modelData.pair();
                }
                onRightClicked: if (modelData.paired) modelData.forget()
            }
        }
    }
}
