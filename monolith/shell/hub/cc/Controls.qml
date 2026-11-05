import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import Quickshell.Services.Mpris
import "../../core"
import "../../ui"

// Control center → Controls: sliders and a grid of toggle tiles on the left; now playing and
// the power actions on the right.
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

    // a toggle tile: icon in a shape that turns accent when on, name and state
    component Tile: Pressable {
        id: tile
        property string icon: ""
        property string title: ""
        property string state: ""
        property bool on: false
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Theme.corner(height, 4)
        color: on ? Theme.accentContainer : Theme.containerHigh
        Rectangle {
            id: tb
            x: 9
            width: 42; height: 42
            anchors.verticalCenter: parent.verticalCenter
            radius: tile.on ? 14 : 21
            color: tile.on ? Theme.accent : Theme.control
            Behavior on radius { NumberAnimation { duration: Theme.springMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.springCurve } }
            Behavior on color { ColorAnimation { duration: 200 } }
            Icon { anchors.centerIn: parent; name: tile.icon; size: 21; filled: tile.on; color: tile.on ? Theme.onAccent : Theme.text }
        }
        Column {
            anchors.left: tb.right; anchors.leftMargin: 11
            anchors.right: parent.right; anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; text: tile.title; strong: true; color: tile.on ? Theme.onAccentContainer : Theme.text }
            Label { width: parent.width; text: tile.state !== "" ? tile.state : (tile.on ? "On" : "Off"); muted: !tile.on; color: tile.on ? Theme.onAccentContainer : Theme.subtext; font.pixelSize: Theme.sizeSmall }
        }
    }

    // ── left: sliders, then tiles ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 620
        Layout.fillHeight: true
        spacing: 10

        Card {
            Layout.fillWidth: true
            Layout.preferredHeight: sliders.implicitHeight + 2 * pad
            ColumnLayout {
                id: sliders
                width: parent.width
                spacing: 8
                Slider {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    icon: cc.sink && cc.sink.audio && cc.sink.audio.muted ? "volume_off" : "volume_up"
                    muted: !!(cc.sink && cc.sink.audio && cc.sink.audio.muted)
                    value: cc.sink && cc.sink.audio ? cc.sink.audio.volume : 0
                    onMoved: v => { if (cc.sink && cc.sink.audio) { cc.sink.audio.muted = false; cc.sink.audio.volume = v; } }
                    onIconClicked: if (cc.sink && cc.sink.audio) cc.sink.audio.muted = !cc.sink.audio.muted
                }
                Slider {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    icon: cc.source && cc.source.audio && cc.source.audio.muted ? "mic_off" : "mic"
                    muted: !!(cc.source && cc.source.audio && cc.source.audio.muted)
                    value: cc.source && cc.source.audio ? cc.source.audio.volume : 0
                    onMoved: v => { if (cc.source && cc.source.audio) cc.source.audio.volume = v; }
                    onIconClicked: if (cc.source && cc.source.audio) cc.source.audio.muted = !cc.source.audio.muted
                }
                Slider {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    visible: cc.brightness >= 0
                    icon: "light_mode"
                    value: Math.max(0, cc.brightness)
                    onMoved: v => { cc.brightness = v; Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.max(1, Math.round(v * 100)) + "%"]); }
                }
            }
        }

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
    }

    // ── right: now playing, power ──
    ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredWidth: 380
        Layout.fillHeight: true
        spacing: 10

        Card {
            Layout.fillWidth: true
            Layout.fillHeight: true
            pad: 0
            clip: true
            // the album art fills the card, the text and controls sit on a fade over it
            Image {
                anchors.fill: parent
                source: cc.player ? (cc.player.trackArtUrl || "") : ""
                fillMode: Image.PreserveAspectCrop
                sourceSize: Qt.size(600, 600)
                asynchronous: true
                opacity: 0.85
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient {
                    GradientStop { position: 0.0; color: Qt.alpha(Theme.container, 0.15) }
                    GradientStop { position: 0.55; color: Qt.alpha(Theme.container, 0.75) }
                    GradientStop { position: 1.0; color: Theme.container }
                }
            }
            Icon { visible: !cc.player; anchors.centerIn: parent; anchors.verticalCenterOffset: -30; name: "music_note"; size: 54; color: Theme.faint }
            Column {
                x: 16
                width: parent.width - 32
                anchors.bottom: parent.bottom
                anchors.bottomMargin: 16
                spacing: 4
                Label { width: parent.width; text: cc.player ? (cc.player.trackTitle || "Unknown") : "Nothing playing"; strong: true; font.pixelSize: Theme.sizeTitle + 2 }
                Label { width: parent.width; text: cc.player ? (cc.player.trackArtist || "") : "Play something and it shows here"; muted: true }
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
                    Pressable { width: 44; height: 44; color: Theme.containerHigh; enabledInput: !!cc.player && cc.player.canGoPrevious; onClicked: cc.player.previous(); Icon { anchors.centerIn: parent; name: "skip_previous"; size: 22; filled: true } }
                    Pressable {
                        width: 64; height: 44
                        color: Theme.accent; ink: Theme.onAccent
                        enabledInput: !!cc.player
                        onClicked: cc.player.togglePlaying()
                        Icon { anchors.centerIn: parent; name: cc.player && cc.player.isPlaying ? "pause" : "play_arrow"; size: 24; filled: true; color: Theme.onAccent }
                    }
                    Pressable { width: 44; height: 44; color: Theme.containerHigh; enabledInput: !!cc.player && cc.player.canGoNext; onClicked: cc.player.next(); Icon { anchors.centerIn: parent; name: "skip_next"; size: 22; filled: true } }
                    Pressable { width: 44; height: 44; color: Theme.containerHigh; onClicked: HubState.page = "media"; Icon { anchors.centerIn: parent; name: "open_in_full"; size: 19 } }
                }
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Repeater {
                model: [
                    ["lock", "Lock", () => { HubState.close(); LockState.lock(); }],
                    ["bedtime", "Suspend", () => { HubState.close(); Quickshell.execDetached(["loginctl", "suspend"]); }],
                    ["logout", "Log out", () => Niri.action(["quit"])],
                    ["restart_alt", "Restart", () => Quickshell.execDetached(["loginctl", "reboot"])],
                    ["power_settings_new", "Power off", () => Quickshell.execDetached(["loginctl", "poweroff"])]
                ]
                Pressable {
                    required property var modelData
                    required property int index
                    Layout.fillWidth: true
                    Layout.preferredHeight: 48
                    color: index === 4 ? Qt.alpha(Theme.danger, hovered ? 0.32 : 0.2) : Theme.containerHigh
                    onClicked: modelData[2]()
                    Icon { anchors.centerIn: parent; name: parent.modelData[0]; size: 21; color: parent.index === 4 ? Theme.danger : Theme.text }
                }
            }
        }
    }
}
