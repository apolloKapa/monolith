import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../../core"
import "../../ui"
import "../../wall/faces" as Faces

// Control center → Controls: big toggle tiles with the volume bars under them on the left;
// what's playing and the power actions on the right.
RowLayout {
    id: cc
    spacing: 10

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource
    readonly property var bt: Bluetooth.defaultAdapter
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] || null

    // ── state read from the system (polled while open) ──
    property bool wifiOn: false
    property real brightness: -1          // -1: no backlight (desktop)
    property string profile: ""           // power-profiles-daemon: power-saver | balanced | performance
    function poll() { wifiProc.running = true; briProc.running = true; profProc.running = true; }
    Process { id: wifiProc; command: ["nmcli", "-t", "radio", "wifi"]; stdout: StdioCollector { onStreamFinished: cc.wifiOn = text.trim() === "enabled" } }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -c backlight -m 2>/dev/null | head -1 | cut -d, -f4"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); cc.brightness = isNaN(v) ? -1 : v / 100; } }
    }
    Process { id: profProc; command: ["sh", "-c", "powerprofilesctl get 2>/dev/null"]; stdout: StdioCollector { onStreamFinished: cc.profile = text.trim() } }
    Component.onCompleted: poll()
    Timer { interval: 3000; running: HubState.open; repeat: true; onTriggered: cc.poll() }

    // a toggle tile: its icon on top (in a shape that turns accent when on), a dot that says
    // on or off, its name and state below
    component Tile: Pressable {
        id: tile
        property string icon: ""
        property string title: ""
        property string state: ""
        property bool on: false
        Layout.fillWidth: true
        Layout.preferredHeight: 104
        Rise {}
        radius: Theme.corner(56, 8)
        color: on ? Theme.accentContainer : Theme.containerHigh
        Rectangle {
            id: tb
            x: 14; y: 14
            width: 40; height: 40
            radius: tile.on ? 13 : 20
            color: tile.on ? Theme.accent : Theme.control
            scale: tile.pressed ? 0.9 : (tile.hovered ? 1.08 : 1)
            Behavior on scale { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } }
            Behavior on radius { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
            Behavior on color { ColorAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
            Icon { anchors.centerIn: parent; name: tile.icon; size: 21; filled: tile.on; color: tile.on ? Theme.onAccent : Theme.text }
        }
        Rectangle {
            anchors.right: parent.right; anchors.rightMargin: 16
            y: 18
            width: tile.on ? 22 : 8; height: 8; radius: 4
            color: tile.on ? Theme.accent : Theme.faint
            Behavior on width { NumberAnimation { duration: Theme.shortMs; easing.type: Easing.OutBack } }
            Behavior on color { ColorAnimation { duration: Theme.ms(200) } }
        }
        Column {
            x: 16
            width: parent.width - 28
            anchors.bottom: parent.bottom; anchors.bottomMargin: 13
            spacing: 1
            Label { width: parent.width; text: tile.title; strong: true; color: tile.on ? Theme.onAccentContainer : Theme.text }
            Label { width: parent.width; text: tile.state !== "" ? tile.state : (tile.on ? "On" : "Off"); color: tile.on ? Theme.onAccentContainer : Theme.subtext; opacity: tile.on ? 0.8 : 1; font.pixelSize: Theme.sizeSmall }
        }
    }

    // a volume bar with its name beside it
    component Level: RowLayout {
        id: lv
        property string name: ""
        property alias icon: sl.icon
        property alias muted: sl.muted
        property alias value: sl.value
        signal moved(real v)
        signal iconClicked()
        Layout.fillWidth: true
        spacing: 12
        Label { Layout.preferredWidth: 84; text: lv.name; muted: true; font.pixelSize: Theme.sizeSmall + 1 }
        Slider { id: sl; Layout.fillWidth: true; implicitHeight: 36; onMoved: v => lv.moved(v); onIconClicked: lv.iconClicked() }
    }

    // ── left: tiles, then the bars ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 620
        Layout.fillHeight: true
        spacing: 10

        GridLayout {
            Layout.fillWidth: true
            columns: 3
            rowSpacing: 8
            columnSpacing: 8
            Tile {
                icon: "wifi"; title: "Wi-Fi"; on: cc.wifiOn
                onClicked: { cc.wifiOn = !cc.wifiOn; Quickshell.execDetached(["nmcli", "radio", "wifi", cc.wifiOn ? "on" : "off"]); }
                onRightClicked: HubState.page = "network"
            }
            Tile {
                icon: "bluetooth"; title: "Bluetooth"; on: !!(cc.bt && cc.bt.enabled)
                state: !cc.bt ? "No adapter" : ""
                onClicked: if (cc.bt) cc.bt.enabled = !cc.bt.enabled
                onRightClicked: HubState.page = "network"
            }
            Tile {
                icon: "do_not_disturb_on"; title: "Do not disturb"; on: Notifs.dnd
                onClicked: Notifs.dnd = !Notifs.dnd
            }
            Tile {
                icon: "nightlight"; title: "Night light"; on: NightLight.enabled
                state: NightLight.enabled ? NightLight.temp + " K" : "Off"
                onClicked: NightLight.toggle()
                onRightClicked: HubState.openSettings("nightlight")
            }
            Tile {
                icon: "coffee"; title: "Stay awake"; on: Tasks.awake
                onClicked: Tasks.awake = !Tasks.awake
            }
            Tile {
                icon: "airplanemode_active"; title: "Airplane mode"
                on: !cc.wifiOn && !(cc.bt && cc.bt.enabled)
                onClicked: {
                    const goOff = cc.wifiOn || (cc.bt && cc.bt.enabled);
                    cc.wifiOn = !goOff;
                    Quickshell.execDetached(["nmcli", "radio", "wifi", goOff ? "off" : "on"]);
                    if (cc.bt) cc.bt.enabled = !goOff;
                }
            }
            Tile {
                icon: cc.profile === "performance" ? "bolt" : (cc.profile === "power-saver" ? "energy_savings_leaf" : "balance")
                title: "Power mode"
                on: cc.profile === "performance"
                state: cc.profile === "" ? "—" : cc.profile.charAt(0).toUpperCase() + cc.profile.slice(1).replace("-", " ")
                onClicked: {
                    const order = ["power-saver", "balanced", "performance"];
                    cc.profile = order[(order.indexOf(cc.profile) + 1) % order.length];
                    Quickshell.execDetached(["powerprofilesctl", "set", cc.profile]);
                }
            }
            Tile {
                icon: "keyboard"; title: "Keyboard"; on: false
                state: Niri.layoutName !== "" ? Niri.layoutName : "—"
                onClicked: Niri.action(["switch-layout", "next"])
            }
            Tile {
                icon: Tasks.recording ? "stop_circle" : "screen_record"; title: Tasks.recording ? "Recording" : "Record"
                on: Tasks.recording
                state: Tasks.recording ? Tasks.fmt(Tasks.recSeconds) + " · stop" : "A region"
                onClicked: { if (Tasks.recording) Tasks.stopRecording(); else { HubState.close(); Tasks.startRecording(true); } }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: levels.implicitHeight + 28
            Rise {}
            radius: Theme.corner(56, 8)
            color: Theme.container
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            ColumnLayout {
                id: levels
                x: 16; y: 14
                width: parent.width - 32
                spacing: 8
                Level {
                    name: "Volume"
                    icon: cc.sink && cc.sink.audio && cc.sink.audio.muted ? "volume_off" : "volume_up"
                    muted: !!(cc.sink && cc.sink.audio && cc.sink.audio.muted)
                    value: cc.sink && cc.sink.audio ? cc.sink.audio.volume : 0
                    onMoved: v => { if (cc.sink && cc.sink.audio) { cc.sink.audio.muted = false; cc.sink.audio.volume = v; } }
                    onIconClicked: if (cc.sink && cc.sink.audio) cc.sink.audio.muted = !cc.sink.audio.muted
                }
                Level {
                    name: "Microphone"
                    icon: cc.source && cc.source.audio && cc.source.audio.muted ? "mic_off" : "mic"
                    muted: !!(cc.source && cc.source.audio && cc.source.audio.muted)
                    value: cc.source && cc.source.audio ? cc.source.audio.volume : 0
                    onMoved: v => { if (cc.source && cc.source.audio) cc.source.audio.volume = v; }
                    onIconClicked: if (cc.source && cc.source.audio) cc.source.audio.muted = !cc.source.audio.muted
                }
                Level {
                    visible: cc.brightness >= 0
                    name: "Brightness"
                    icon: "light_mode"
                    value: Math.max(0, cc.brightness)
                    onMoved: v => { cc.brightness = v; Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.max(1, Math.round(v * 100)) + "%"]); }
                }
            }
        }
    }

    // ── right: what's playing, power ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 380
        Layout.fillHeight: true
        spacing: 10

        Rectangle {
            Layout.fillWidth: true
            Layout.fillHeight: true
            radius: Theme.corner(56, 8)
            color: Theme.container
            border.width: Theme.outlineW
            border.color: Theme.outlineColor
            // the cover as a rounded picture, the words and buttons under it
            Rectangle {
                id: cover
                anchors.horizontalCenter: parent.horizontalCenter
                y: 18
                width: Math.max(80, Math.min(parent.width - 36, parent.height - 190))
                height: width
                radius: Theme.corner(56, 6)
                color: Theme.control
                Icon { visible: art.status !== Image.Ready; anchors.centerIn: parent; name: cc.player ? "music_note" : "music_off"; size: 48; color: Theme.faint }
                Image {
                    id: art
                    anchors.fill: parent
                    source: cc.player ? (cc.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    clip: true
                    sourceSize: Qt.size(600, 600)
                    asynchronous: true
                }
                // the sound, dancing along the bottom of the cover while it plays
                Rectangle {
                    visible: cvb.live
                    anchors.bottom: parent.bottom
                    width: parent.width; height: parent.height * 0.45
                    gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.55) } }
                }
                Faces.CavaBars {
                    id: cvb
                    anchors.bottom: parent.bottom; anchors.bottomMargin: 12
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: parent.width - 32; height: parent.height * 0.3
                    count: 24; spacing: 3; minLen: 3
                    live: !!cc.player && cc.player.isPlaying
                    visible: live
                    color: "#ffffff"
                }
                // rounded corners over the picture (clip only cuts to the box)
                Rectangle { anchors.fill: parent; anchors.margins: -cover.radius; radius: cover.radius * 2; color: "transparent"; border.width: cover.radius; border.color: Theme.container; visible: art.status === Image.Ready }
            }
            Column {
                x: 18
                width: parent.width - 36
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                spacing: 4
                Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cc.player ? (cc.player.trackTitle || "Unknown") : "Nothing playing"; strong: true; font.pixelSize: Theme.sizeTitle + 1 }
                Label { width: parent.width; horizontalAlignment: Text.AlignHCenter; text: cc.player ? (cc.player.trackArtist || "") : "Play something and it shows up here"; muted: true }
                Item { width: 1; height: 8 }
                // progress
                Rectangle {
                    visible: !!cc.player && cc.player.lengthSupported
                    width: parent.width; height: 4; radius: 2
                    color: Theme.ringTrack
                    Rectangle {
                        height: parent.height; radius: 2
                        color: Theme.accent
                        width: cc.player && cc.player.length > 0 ? parent.width * Math.min(1, cc.player.position / cc.player.length) : 0
                    }
                    Timer { running: !!cc.player && cc.player.isPlaying; interval: 1000; repeat: true; onTriggered: cc.player.positionChanged() }
                }
                Item { width: 1; height: 6 }
                Row {
                    spacing: 8
                    anchors.horizontalCenter: parent.horizontalCenter
                    Pressable { width: 44; height: 44; color: Theme.containerHigh; enabledInput: !!cc.player && cc.player.canGoPrevious; opacity: enabledInput ? 1 : 0.4; onClicked: cc.player.previous(); Icon { anchors.centerIn: parent; name: "skip_previous"; size: 22; filled: true } }
                    Pressable {
                        width: 72; height: 44
                        color: Theme.accent; ink: Theme.onAccent
                        enabledInput: !!cc.player
                        opacity: enabledInput ? 1 : 0.4
                        onClicked: cc.player.togglePlaying()
                        Icon { anchors.centerIn: parent; name: cc.player && cc.player.isPlaying ? "pause" : "play_arrow"; size: 24; filled: true; color: Theme.onAccent }
                    }
                    Pressable { width: 44; height: 44; color: Theme.containerHigh; enabledInput: !!cc.player && cc.player.canGoNext; opacity: enabledInput ? 1 : 0.4; onClicked: cc.player.next(); Icon { anchors.centerIn: parent; name: "skip_next"; size: 22; filled: true } }
                    Pressable { width: 44; height: 44; color: Theme.containerHigh; onClicked: HubState.page = "media"; Icon { anchors.centerIn: parent; name: "open_in_full"; size: 19 } }
                }
            }
        }

        // power: each with its name under it; the last three ask again before they do it
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    ["lock", "Lock", () => { HubState.close(); LockState.lock(); }, false],
                    ["bedtime", "Sleep", () => { HubState.close(); Power.suspend(); }, false],
                    ["logout", "Log out", () => Power.logout(), true],
                    ["restart_alt", "Restart", () => Power.reboot(), true],
                    ["power_settings_new", "Off", () => Power.poweroff(), true]
                ]
                Pressable {
                    id: pb
                    required property var modelData
                    required property int index
                    property bool armed: false
                    Layout.fillWidth: true
                    Layout.preferredHeight: 64
                    Rise { delay: 200 + pb.index * 45 }
                    radius: Theme.corner(56, 4)
                    color: armed ? Theme.danger : (index === 4 ? Qt.alpha(Theme.danger, hovered ? 0.32 : 0.2) : Theme.containerHigh)
                    onClicked: {
                        if (modelData[3] && !armed) { armed = true; disarm.restart(); return; }
                        armed = false;
                        modelData[2]();
                    }
                    Timer { id: disarm; interval: 3000; onTriggered: pb.armed = false }
                    Column {
                        anchors.centerIn: parent
                        spacing: 3
                        Icon { anchors.horizontalCenter: parent.horizontalCenter; name: pb.armed ? "help" : pb.modelData[0]; size: 21; color: pb.armed ? Theme.m("on_error", "#ffffff") : (pb.index === 4 ? Theme.danger : Theme.text) }
                        Label { anchors.horizontalCenter: parent.horizontalCenter; text: pb.armed ? "Sure?" : pb.modelData[1]; font.pixelSize: Theme.sizeSmall; strong: pb.armed; color: pb.armed ? Theme.m("on_error", "#ffffff") : (pb.index === 4 ? Theme.danger : Theme.subtext) }
                    }
                }
            }
        }
    }
}
