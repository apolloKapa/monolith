import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import "../core"
import "../ui"

// Network: Wi-Fi (what you're on, the networks nearby, a password asked for in place),
// the wired connection and Bluetooth devices. Each tab opens with a card saying how things
// stand, and says what to do when there's nothing to list.
Page {
    id: page
    pageId: "network"
    implicitHeight: Math.min(600, col.implicitHeight)
    property string tab: "wifi"

    property var devices: []          // nmcli devices
    property var ips: ({})            // device -> its IPv4 address
    property var saved: ({})          // names of the saved Wi-Fi connections
    property bool wifiOn: false
    property var activeNet: null      // the Wi-Fi network we're on
    property bool listed: false       // a first scan came back
    property bool scanning: false

    // the one network that's opened up: for its password ("pw") or its details ("info")
    property string openSsid: ""
    property string openMode: "pw"
    property string busy: ""          // the network being connected to
    property string error: ""         // what went wrong, in words
    property string errorSsid: ""
    signal failed(string ssid)

    readonly property var ethernet: devices.filter(d => d.type === "ethernet")
    readonly property var wifiDev: devices.find(d => d.type === "wifi") || null
    readonly property var adapter: Bluetooth.defaultAdapter
    readonly property bool btOn: !!(adapter && adapter.enabled)
    readonly property var btDevices: Bluetooth.devices.values.slice().sort((a, b) => (b.connected - a.connected) || (b.paired - a.paired))
    readonly property var btConnected: btDevices.filter(d => d.connected)

    function strengthWord(s) { return s > 70 ? "Strong signal" : (s > 40 ? "Good signal" : "Weak signal"); }
    function strengthIcon(s) { return s > 75 ? "signal_wifi_4_bar" : (s > 50 ? "network_wifi_3_bar" : (s > 25 ? "network_wifi_2_bar" : "network_wifi_1_bar")); }
    function stateWord(s) {
        if (s === "connected") return "Connected";
        if (s === "unavailable") return "Cable unplugged";
        if (s === "disconnected") return "Not connected";
        return s.charAt(0).toUpperCase() + s.slice(1);
    }
    // one line of nmcli's terse output: fields split at ":", with "\:" and "\\" unescaped
    function fields(line) {
        const out = [];
        let cur = "";
        for (let i = 0; i < line.length; i++) {
            const ch = line[i];
            if (ch === "\\" && i + 1 < line.length) cur += line[++i];
            else if (ch === ":") { out.push(cur); cur = ""; }
            else cur += ch;
        }
        out.push(cur);
        return out;
    }

    function remember() { if (restoring) return; HubState.netCache = { devices: devices, ips: ips, saved: saved, wifiOn: wifiOn, list: HubState.netCache.list }; }
    onDevicesChanged: remember()
    onWifiOnChanged: remember()
    onIpsChanged: remember()
    // what it found last time, until nmcli answers (read once: bound, it would loop through remember())
    property bool restoring: true
    Component.onCompleted: {
        const c = HubState.netCache;
        if (c.devices) { devices = c.devices; ips = c.ips || ({}); saved = c.saved || ({}); wifiOn = c.wifiOn === true; }
        if (c.list) { sync(c.list); activeNet = c.list.find(n => n.active) || null; listed = true; }
        restoring = false;
    }
    function refresh() { devProc.running = true; radioProc.running = true; ipProc.running = true; savedProc.running = true; }
    onCurrentChanged: { if (current) refresh(); else closePrompt(); }
    onTabChanged: closePrompt()
    Timer { interval: 5000; repeat: true; running: page.current && HubState.open; onTriggered: page.refresh() }
    Timer { id: soon; interval: 1500; onTriggered: page.refresh() }

    Process {
        id: devProc
        command: ["nmcli", "-t", "-f", "DEVICE,TYPE,STATE,CONNECTION", "dev"]
        stdout: StdioCollector { onStreamFinished: page.devices = text.trim().split("\n").filter(l => l).map(l => { const p = page.fields(l); return { name: p[0], type: p[1], state: p[2], conn: p[3] || "" }; }) }
    }
    Process { id: radioProc; command: ["nmcli", "-t", "radio", "wifi"]; stdout: StdioCollector { onStreamFinished: page.wifiOn = text.trim() === "enabled" } }
    Process {
        id: ipProc
        command: ["nmcli", "-t", "-f", "GENERAL.DEVICE,IP4.ADDRESS", "dev", "show"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                let dev = "";
                for (const l of text.split("\n")) {
                    const p = page.fields(l);
                    if (p[0] === "GENERAL.DEVICE") dev = p[1];
                    else if (p[0].indexOf("IP4.ADDRESS") === 0 && dev !== "" && !map[dev]) map[dev] = (p[1] || "").split("/")[0];
                }
                page.ips = map;
            }
        }
    }
    // the saved connections first: the list marks them, and they connect without asking
    Process {
        id: savedProc
        command: ["nmcli", "-t", "-f", "NAME,TYPE", "connection"]
        stdout: StdioCollector {
            onStreamFinished: {
                const map = {};
                for (const l of text.split("\n")) { const p = page.fields(l); if (p[1] === "802-11-wireless") map[p[0]] = true; }
                page.saved = map;
                wifiProc.running = true;
            }
        }
    }
    Process {
        id: wifiProc
        command: ["nmcli", "-t", "-f", "IN-USE,SSID,SIGNAL,SECURITY", "dev", "wifi", "list", "--rescan", "auto"]
        stdout: StdioCollector {
            onStreamFinished: {
                const seen = {};
                const list = text.split("\n").filter(l => l).map(l => {
                    const p = page.fields(l);
                    const sec = (p[3] || "").trim();
                    return { active: p[0] === "*", ssid: p[1] || "", strength: parseInt(p[2]) || 0, secure: sec !== "" && sec !== "--", security: sec === "--" ? "" : sec, saved: page.saved[p[1]] === true };
                }).sort((a, b) => (b.active - a.active) || (b.saved - a.saved) || (b.strength - a.strength))
                  .filter(n => n.ssid !== "" && !seen[n.ssid] && (seen[n.ssid] = true));
                page.sync(list);
                page.activeNet = list.find(n => n.active) || null;
                HubState.netCache = Object.assign({}, HubState.netCache, { list: list });
                page.listed = true;
            }
        }
    }
    Process { id: scanProc; command: ["nmcli", "dev", "wifi", "rescan"]; onExited: { page.scanning = false; page.refresh(); } }
    function rescan() { if (scanning) return; scanning = true; scanProc.running = true; }

    // The list is kept in place (rows are updated, not rebuilt), so a password being typed
    // and the opened row survive the refresh every few seconds; rows keep their order too,
    // only the connected one moves to the top.
    ListModel { id: nets }
    function find(ssid) { for (let i = 0; i < nets.count; i++) if (nets.get(i).ssid === ssid) return i; return -1; }
    function sync(list) {
        for (let i = nets.count - 1; i >= 0; i--) {
            const s = nets.get(i).ssid;
            if (s !== openSsid && s !== busy && !list.some(n => n.ssid === s)) nets.remove(i);
        }
        for (const n of list) {
            const i = find(n.ssid);
            if (i < 0) nets.append(n); else nets.set(i, n);
        }
        for (let i = 1; i < nets.count; i++) if (nets.get(i).active) nets.move(i, 0, 1);
    }

    function closePrompt() { openSsid = ""; error = ""; errorSsid = ""; }
    function openRow(ssid, mode) { error = ""; errorSsid = ""; openMode = mode; openSsid = ssid; }
    function setWifi(on) {
        wifiOn = on;
        if (!on) { nets.clear(); listed = false; activeNet = null; closePrompt(); }
        Quickshell.execDetached(["nmcli", "radio", "wifi", on ? "on" : "off"]);
        soon.restart();
    }
    // only ever removes a Wi-Fi connection of that name
    function forget(ssid) {
        Quickshell.execDetached(["sh", "-c", 'if [ "$(nmcli -g connection.type connection show id "$1" 2>/dev/null)" = 802-11-wireless ]; then nmcli connection delete id "$1"; fi', "sh", ssid]);
        soon.restart();
    }
    function disconnectWifi() {
        if (wifiDev) Quickshell.execDetached(["nmcli", "dev", "disconnect", wifiDev.name]);
        closePrompt();
        soon.restart();
    }

    Process {
        id: connectProc
        property string ssid: ""
        property bool hadPw: false
        property bool wasSaved: false
        property int code: -1
        property bool gotText: false
        property string said: ""
        stderr: StdioCollector { onStreamFinished: { connectProc.said = text; connectProc.gotText = true; page.connected(); } }
        onExited: c => { code = c; page.connected(); }
    }
    // With a password: an older saved connection of that name goes first (a stale or half-made
    // one makes nmcli fail whatever is typed), then a fresh one is made.
    function connect(ssid, password) {
        if (busy !== "") return;
        error = ""; errorSsid = "";
        busy = ssid;
        connectProc.ssid = ssid;
        connectProc.hadPw = password !== "";
        connectProc.wasSaved = saved[ssid] === true;
        connectProc.code = -1;
        connectProc.gotText = false;
        connectProc.command = password !== ""
            ? ["sh", "-c", 'if [ "$(nmcli -g connection.type connection show id "$1" 2>/dev/null)" = 802-11-wireless ]; then nmcli connection delete id "$1" >/dev/null 2>&1; fi; exec nmcli -w 45 dev wifi connect "$1" password "$2"', "sh", ssid, password]
            : ["nmcli", "-w", "45", "dev", "wifi", "connect", ssid];
        connectProc.running = true;
    }
    // the answer: in, or why not (a wrong password asks again, anything else says what it was)
    function connected() {
        const p = connectProc;
        if (p.code < 0 || !p.gotText || busy === "") return;
        const ssid = p.ssid;
        busy = "";
        if (p.code === 0) {
            if (openSsid === ssid) closePrompt();
            refresh();
            return;
        }
        const i = find(ssid);
        const secure = i >= 0 && nets.get(i).secure;
        const said = p.said.trim();
        const secrets = /secrets were required|no secrets|\bpsk\b|password|key-mgmt|wireless-security/i.test(said);
        const timeout = /timeout/i.test(said);
        // what a failed first try leaves behind would get in the way of the next one
        if (!p.wasSaved || p.hadPw) forget(ssid);
        errorSsid = ssid;
        if (secure && (secrets || (timeout && p.hadPw))) {
            error = p.hadPw ? "That password didn't work. Check it and try again."
                            : (p.wasSaved ? "The saved password no longer works. Enter the new one." : "This network needs a password.");
            openMode = "pw";
            openSsid = ssid;
        } else if (/no network with ssid|could not be found/i.test(said)) {
            error = "This network is out of range now.";
        } else if (timeout) {
            error = "It took too long to connect. Try again closer to the router.";
        } else {
            const last = said.split("\n").filter(l => l).pop() || "";
            error = last.replace(/^Error:\s*/, "").replace(/^Connection activation failed:\s*/, "").replace(/^\(\d+\)\s*/, "") || "Couldn't connect.";
        }
        failed(ssid);
        refresh();
    }

    component Entry: Pressable {
        id: r
        property string icon: ""
        property string title: ""
        property string sub: ""
        property bool on: false
        property string trailing: ""
        Rise {}
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
        Icon { id: tr; anchors.right: parent.right; anchors.rightMargin: 16; anchors.verticalCenter: parent.verticalCenter; name: r.trailing; size: 18; color: Theme.subtext; visible: r.trailing !== "" }
    }

    // scrolls when there's more than fits
    Flickable {
        id: scroller
        SmoothWheel {}
        anchors.fill: parent
        contentHeight: col.implicitHeight
        clip: true
        boundsBehavior: Flickable.StopAtBounds
        interactive: contentHeight > height
        ColumnLayout {
            id: col
            width: parent.width
            spacing: 8

            IconTabs {
                opts: [["wifi", "Wi-Fi", "wifi"], ["wired", "Ethernet", "lan"], ["bt", "Bluetooth", "bluetooth"]]
                value: page.tab
                onPicked: v => page.tab = v
            }

            // ── Wi-Fi ──
            Hero {
                visible: page.tab === "wifi" && page.wifiDev !== null
                icon: !page.wifiOn ? "wifi_off" : (page.activeNet ? page.strengthIcon(page.activeNet.strength) : "wifi_find")
                title: !page.wifiOn ? "Wi-Fi is off" : (page.activeNet ? page.activeNet.ssid : "Not connected")
                sub: !page.wifiOn ? "Turn it on to see the networks around you"
                    : (page.activeNet ? ["Connected", page.strengthWord(page.activeNet.strength), page.ips[page.wifiDev ? page.wifiDev.name : ""] || ""].filter(s => s !== "").join("  ·  ")
                                      : "Pick a network below to get online")
                on: page.wifiOn
                lit: page.wifiOn && page.activeNet !== null
                onToggled: v => page.setWifi(v)
            }
            SectionHead {
                visible: page.tab === "wifi" && page.wifiOn && nets.count > 0
                text: "Networks nearby"
                action: "refresh"
                hint: page.scanning ? "Looking…" : "Scan again"
                spinning: page.scanning
                onActed: page.rescan()
            }
            Repeater {
                model: page.tab === "wifi" && page.wifiOn ? nets : null
                Rectangle {
                    id: net
                    required property string ssid
                    required property int strength
                    required property bool secure
                    required property string security
                    required property bool active
                    required property bool saved
                    readonly property bool opened: page.openSsid === ssid
                    readonly property bool busy: page.busy === ssid
                    readonly property bool asking: page.openMode === "pw" && !active
                    readonly property string trouble: page.errorSsid === ssid ? page.error : ""
                    // WPA wants 8 characters at least; anything older, anything at all
                    readonly property int minLen: /WPA|SAE|RSN/i.test(security) ? 8 : 1
                    property bool reveal: false
                    Rise {}
                    property real extra: opened ? panel.implicitHeight + 14 : 0
                    Behavior on extra { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                    Layout.fillWidth: true
                    Layout.preferredHeight: 56 + extra
                    radius: Theme.corner(56)
                    color: active ? Theme.selected : (opened ? Theme.container : Theme.containerHigh)
                    border.width: Theme.outlineW
                    border.color: Theme.outlineColor
                    clip: true
                    Behavior on color { ColorAnimation { duration: Theme.ms(220); easing.type: Easing.OutCubic } }

                    function submit() { if (pw.text.length >= minLen && !busy) page.connect(ssid, pw.text); }
                    function fold() { const had = pw.activeFocus; pw.text = ""; reveal = false; if (had) HubState.refocus(); }
                    onOpenedChanged: { if (opened && asking) pw.forceActiveFocus(); else if (!opened) fold(); }
                    Component.onDestruction: if (pw.activeFocus) HubState.refocus()
                    Connections {
                        target: page
                        function onFailed(s) { if (s === net.ssid && net.opened && net.asking) { pw.forceActiveFocus(); pw.selectAll(); } }
                    }

                    Pressable {
                        id: head
                        width: parent.width
                        height: 56
                        color: "transparent"
                        // a click: the connected one opens up, a known or open one connects,
                        // a new one with a lock asks for its password
                        onClicked: {
                            if (net.busy) return;
                            if (net.opened) page.closePrompt();
                            else if (net.active) page.openRow(net.ssid, "info");
                            else if (net.secure && !net.saved) page.openRow(net.ssid, "pw");
                            else { page.closePrompt(); page.connect(net.ssid, ""); }
                        }
                        onRightClicked: if (!net.busy && (net.saved || net.active)) { if (net.opened) page.closePrompt(); else page.openRow(net.ssid, "info"); }
                        Bubble { id: nb; x: 10; anchors.verticalCenter: parent.verticalCenter; size: 36; icon: page.strengthIcon(net.strength); on: net.active }
                        Column {
                            anchors.left: nb.right; anchors.leftMargin: 12
                            anchors.right: tail.left; anchors.rightMargin: 8
                            anchors.verticalCenter: parent.verticalCenter
                            Label { width: parent.width; text: net.ssid; strong: true }
                            Label {
                                width: parent.width
                                font.pixelSize: Theme.sizeSmall
                                readonly property bool bad: net.trouble !== "" && !net.opened && !net.busy
                                color: bad ? Theme.danger : Theme.subtext
                                text: net.busy ? "Connecting…" : (bad ? net.trouble
                                    : (net.active ? "Connected" : ((net.saved ? "Saved" : (net.secure ? "Needs a password" : "Open, no password")) + "  ·  " + page.strengthWord(net.strength))))
                            }
                        }
                        Row {
                            id: tail
                            anchors.right: parent.right; anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Icon {
                                visible: net.busy
                                anchors.verticalCenter: parent.verticalCenter
                                name: "progress_activity"; size: 20; color: Theme.accent
                                RotationAnimator on rotation { running: net.busy; from: 0; to: 360; duration: 900; loops: Animation.Infinite }
                            }
                            Icon { visible: !net.busy && net.secure && !net.saved && !net.active; anchors.verticalCenter: parent.verticalCenter; name: "lock"; size: 18; color: Theme.subtext }
                            Icon { visible: !net.busy && net.active; anchors.verticalCenter: parent.verticalCenter; name: "check_circle"; filled: true; size: 20; color: Theme.accent }
                            // a known network's details (forget it, disconnect)
                            Pressable {
                                visible: !net.busy && (net.saved || net.active)
                                anchors.verticalCenter: parent.verticalCenter
                                width: 32; height: 32
                                color: "transparent"
                                onClicked: { if (net.opened) page.closePrompt(); else page.openRow(net.ssid, "info"); }
                                Icon {
                                    anchors.centerIn: parent; name: "expand_more"; size: 20; color: Theme.subtext
                                    rotation: net.opened ? 180 : 0
                                    Behavior on rotation { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }
                                }
                            }
                        }
                    }

                    Column {
                        id: panel
                        x: 14
                        y: 58
                        width: parent.width - 28
                        spacing: 8
                        opacity: net.opened ? 1 : 0
                        visible: net.extra > 1
                        Behavior on opacity { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutCubic } }

                        // the password, asked for in place
                        Item {
                            visible: net.asking
                            width: parent.width
                            height: 44
                            Rectangle {
                                anchors.left: parent.left
                                anchors.right: go.left; anchors.rightMargin: 8
                                height: parent.height
                                radius: Theme.corner(height)
                                color: Theme.containerHigh
                                border.width: pw.activeFocus ? 2 : Theme.outlineW
                                border.color: net.trouble !== "" ? Theme.danger : (pw.activeFocus ? Theme.accent : Theme.outlineColor)
                                Icon { id: key; x: 14; anchors.verticalCenter: parent.verticalCenter; name: "key"; size: 18; color: Theme.subtext }
                                TextInput {
                                    id: pw
                                    anchors.left: key.right; anchors.leftMargin: 10
                                    anchors.right: eye.left; anchors.rightMargin: 4
                                    height: parent.height
                                    verticalAlignment: TextInput.AlignVCenter
                                    echoMode: net.reveal ? TextInput.Normal : TextInput.Password
                                    passwordCharacter: "•"
                                    inputMethodHints: Qt.ImhSensitiveData | Qt.ImhNoPredictiveText | Qt.ImhNoAutoUppercase
                                    readOnly: net.busy
                                    clip: true
                                    color: Theme.text
                                    selectionColor: Theme.selected
                                    selectedTextColor: Theme.text
                                    font.family: Theme.fontFamily
                                    font.pixelSize: Theme.sizeBody
                                    maximumLength: 64
                                    onTextEdited: if (net.trouble !== "") { page.error = ""; page.errorSsid = ""; }
                                    onAccepted: net.submit()
                                    Keys.onEscapePressed: page.closePrompt()
                                    Label { anchors.fill: parent; verticalAlignment: Text.AlignVCenter; visible: pw.text === ""; text: "Password"; muted: true }
                                }
                                Pressable {
                                    id: eye
                                    anchors.right: parent.right; anchors.rightMargin: 6
                                    anchors.verticalCenter: parent.verticalCenter
                                    width: 32; height: 32
                                    color: "transparent"
                                    onClicked: { net.reveal = !net.reveal; pw.forceActiveFocus(); }
                                    Icon { anchors.centerIn: parent; name: net.reveal ? "visibility_off" : "visibility"; size: 18; color: Theme.subtext }
                                }
                            }
                            Button {
                                id: go
                                anchors.right: parent.right
                                height: parent.height
                                primary: true
                                text: net.busy ? "Connecting…" : "Connect"
                                enabledInput: !net.busy && pw.text.length >= net.minLen
                                opacity: enabledInput || net.busy ? 1 : 0.45
                                onClicked: net.submit()
                            }
                        }
                        Label {
                            visible: net.asking
                            x: 4
                            width: parent.width - 8
                            font.pixelSize: Theme.sizeSmall
                            color: net.trouble !== "" ? Theme.danger : Theme.subtext
                            text: net.trouble !== "" ? net.trouble
                                : (pw.text.length > 0 && pw.text.length < net.minLen ? "At least " + net.minLen + " characters" : "Enter connects  ·  Esc cancels")
                        }

                        // a known network: what it is, and the ways out
                        Item {
                            visible: !net.asking
                            width: parent.width
                            height: 40
                            Label {
                                x: 4
                                anchors.verticalCenter: parent.verticalCenter
                                anchors.right: acts.left; anchors.rightMargin: 8
                                muted: true
                                text: [net.security !== "" ? net.security : "Open", net.strength + "% signal", net.active ? (page.ips[page.wifiDev ? page.wifiDev.name : ""] || "") : ""].filter(s => s !== "").join("  ·  ")
                            }
                            Row {
                                id: acts
                                anchors.right: parent.right
                                spacing: 8
                                Button { visible: net.saved; text: "Forget"; icon: "delete"; onClicked: { page.forget(net.ssid); page.closePrompt(); } }
                                Button { visible: net.active; text: "Disconnect"; icon: "link_off"; onClicked: page.disconnectWifi() }
                                Button { visible: !net.active; primary: true; text: "Connect"; onClicked: { const s = net.ssid; page.closePrompt(); page.connect(s, ""); } }
                            }
                        }
                    }
                }
            }
            Empty {
                visible: page.tab === "wifi" && page.wifiDev === null
                icon: "wifi_off"
                title: "No Wi-Fi here"
                sub: "This computer has no Wi-Fi adapter, or its driver isn't loaded."
            }
            Empty {
                visible: page.tab === "wifi" && page.wifiDev !== null && !page.wifiOn
                icon: "wifi_off"
                title: "Wi-Fi is off"
                sub: "Turn it on and the networks around you show up here."
                button: "Turn on Wi-Fi"
                buttonIcon: "wifi"
                onActed: page.setWifi(true)
            }
            Empty {
                visible: page.tab === "wifi" && page.wifiDev !== null && page.wifiOn && nets.count === 0
                icon: page.listed && !page.scanning ? "wifi_find" : "progress_activity"
                spinning: !page.listed || page.scanning
                title: page.listed && !page.scanning ? "No networks in range" : "Looking for networks…"
                sub: page.listed && !page.scanning ? "Move closer to a router, then look again." : ""
                button: page.listed && !page.scanning ? "Scan again" : ""
                buttonIcon: "refresh"
                onActed: page.rescan()
            }

            // ── Ethernet ──
            Repeater {
                model: page.tab === "wired" ? page.ethernet : []
                Hero {
                    required property var modelData
                    icon: "lan"
                    title: modelData.conn !== "" ? modelData.conn : "Ethernet"
                    sub: [page.stateWord(modelData.state), modelData.name, modelData.state === "connected" ? (page.ips[modelData.name] || "") : ""].filter(s => s !== "").join("  ·  ")
                    on: modelData.state === "connected"
                    switchable: modelData.state !== "unavailable"
                    onToggled: v => { Quickshell.execDetached(["nmcli", "dev", v ? "connect" : "disconnect", modelData.name]); soon.restart(); }
                }
            }
            Empty {
                visible: page.tab === "wired" && page.ethernet.length === 0
                icon: "lan"
                title: "No wired adapter"
                sub: "Plug in an Ethernet adapter and it shows up here."
            }

            // ── Bluetooth ──
            Hero {
                visible: page.tab === "bt" && page.adapter !== null
                icon: page.btOn ? (page.btConnected.length > 0 ? "bluetooth_connected" : "bluetooth") : "bluetooth_disabled"
                title: !page.btOn ? "Bluetooth is off" : (page.btConnected.length > 0 ? page.btConnected.map(d => d.name || d.address).join(", ") : "Bluetooth is on")
                sub: !page.btOn ? "Turn it on to use your headphones, mouse or controller"
                    : (page.btConnected.length > 0 ? "Connected" : "Pick a device below, or scan for a new one")
                on: page.btOn
                lit: page.btOn && page.btConnected.length > 0
                onToggled: v => { if (page.adapter) page.adapter.enabled = v; }
            }
            SectionHead {
                visible: page.tab === "bt" && page.btOn && page.btDevices.length > 0
                text: "Devices"
                action: page.adapter && page.adapter.discovering ? "progress_activity" : "bluetooth_searching"
                hint: page.adapter && page.adapter.discovering ? "Looking… click to stop" : "Find new devices"
                spinning: !!(page.adapter && page.adapter.discovering)
                onActed: if (page.adapter) page.adapter.discovering = !page.adapter.discovering
            }
            Repeater {
                model: page.tab === "bt" && page.btOn ? page.btDevices : []
                Entry {
                    required property var modelData
                    icon: modelData.icon && modelData.icon.indexOf("audio") !== -1 ? "headphones" : (modelData.icon && modelData.icon.indexOf("input") !== -1 ? "mouse" : "devices")
                    title: modelData.name || modelData.address
                    sub: modelData.connected ? ("Connected" + (modelData.batteryAvailable ? "  ·  " + Math.round(modelData.battery * 100) + "% battery" : "")) : (modelData.paired ? "Paired  ·  click to connect" : "New  ·  click to pair")
                    on: modelData.connected
                    trailing: modelData.connected ? "check_circle" : (modelData.paired ? "" : "add_link")
                    onClicked: {
                        if (modelData.connected) modelData.disconnect();
                        else if (modelData.paired) modelData.connect();
                        else modelData.pair();
                    }
                    onRightClicked: if (modelData.paired) modelData.forget()
                }
            }
            Label {
                visible: page.tab === "bt" && page.btOn && page.btDevices.some(d => d.paired)
                Layout.fillWidth: true
                Layout.topMargin: 2
                horizontalAlignment: Text.AlignHCenter
                font.pixelSize: Theme.sizeSmall
                muted: true
                text: "Right-click a paired device to forget it"
            }
            Empty {
                visible: page.tab === "bt" && page.adapter === null
                icon: "bluetooth_disabled"
                title: "No Bluetooth here"
                sub: "This computer has no Bluetooth adapter, or its service isn't running."
            }
            Empty {
                visible: page.tab === "bt" && page.adapter !== null && !page.btOn
                icon: "bluetooth_disabled"
                title: "Bluetooth is off"
                sub: "Turn it on to connect headphones, a mouse or a controller."
                button: "Turn on Bluetooth"
                buttonIcon: "bluetooth"
                onActed: if (page.adapter) page.adapter.enabled = true
            }
            Empty {
                visible: page.tab === "bt" && page.btOn && page.btDevices.length === 0
                icon: page.adapter && page.adapter.discovering ? "progress_activity" : "bluetooth_searching"
                spinning: !!(page.adapter && page.adapter.discovering)
                title: page.adapter && page.adapter.discovering ? "Looking for devices…" : "No devices yet"
                sub: "Put your device in pairing mode so it can be found."
                button: page.adapter && page.adapter.discovering ? "" : "Find devices"
                buttonIcon: "bluetooth_searching"
                onActed: if (page.adapter) page.adapter.discovering = true
            }
        }
    }
}
