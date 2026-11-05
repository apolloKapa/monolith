import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import Quickshell.Bluetooth
import Quickshell.Services.Pipewire
import "../core"
import "../ui"

// Quick: sound and brightness, the toggles, and the power actions.
Page {
    id: page
    pageId: "quick"
    implicitHeight: col.implicitHeight

    PwObjectTracker { objects: [Pipewire.defaultAudioSink, Pipewire.defaultAudioSource] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property var source: Pipewire.defaultAudioSource

    // ── state read from the system ──
    property bool wifiOn: false
    property bool nightOn: false
    property real brightness: -1          // -1: no backlight (desktop)
    readonly property var bt: Bluetooth.defaultAdapter

    function poll() { wifiProc.running = true; nightProc.running = true; briProc.running = true; }
    Process { id: wifiProc; command: ["nmcli", "-t", "radio", "wifi"]; stdout: StdioCollector { onStreamFinished: page.wifiOn = text.trim() === "enabled" } }
    Process { id: nightProc; command: ["pgrep", "-x", "wlsunset"]; onExited: code => page.nightOn = code === 0 }
    Process {
        id: briProc
        command: ["sh", "-c", "brightnessctl -c backlight -m 2>/dev/null | head -1 | cut -d, -f4"]
        stdout: StdioCollector { onStreamFinished: { const v = parseInt(text); page.brightness = isNaN(v) ? -1 : v / 100; } }
    }
    onCurrentChanged: if (current) poll()
    Timer { interval: 3000; running: page.current && HubState.open; repeat: true; onTriggered: page.poll() }

    // stay awake: hold an idle inhibitor while on
    property bool awake: false
    IdleInhibitor { enabled: page.awake; window: page.Window.window }

    component Tile: Pressable {
        id: tile
        property string icon: ""
        property string title: ""
        property string state: ""
        property bool on: false
        Layout.fillWidth: true
        Layout.preferredHeight: 60
        radius: Theme.corner(height)
        color: on ? Theme.selected : Theme.containerHigh
        Bubble {
            id: tb
            x: 10
            anchors.verticalCenter: parent.verticalCenter
            size: 40
            icon: tile.icon
            on: tile.on
        }
        Column {
            anchors.left: tb.right
            anchors.leftMargin: 10
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            Label { width: parent.width; text: tile.title; strong: true }
            Label { width: parent.width; text: tile.state !== "" ? tile.state : (tile.on ? "On" : "Off"); muted: true; font.pixelSize: Theme.sizeSmall }
        }
    }

    component PowerButton: Pressable {
        property string icon: ""
        property string tip: ""
        Layout.fillWidth: true
        Layout.preferredHeight: 52
        radius: Theme.corner(height)
        Icon { anchors.centerIn: parent; name: parent.icon; size: 22 }
    }

    ColumnLayout {
        id: col
        width: parent.width
        spacing: 8

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: sliders.implicitHeight + 20
            radius: Theme.corner(56, 10)
            color: Theme.container
            ColumnLayout {
                id: sliders
                x: 10; y: 10
                width: parent.width - 20
                spacing: 8
                Slider {
                    Layout.fillWidth: true
                    icon: page.sink && page.sink.audio && page.sink.audio.muted ? "volume_off" : "volume_up"
                    muted: !!(page.sink && page.sink.audio && page.sink.audio.muted)
                    value: page.sink && page.sink.audio ? page.sink.audio.volume : 0
                    onMoved: v => { if (page.sink && page.sink.audio) { page.sink.audio.muted = false; page.sink.audio.volume = v; } }
                    onIconClicked: if (page.sink && page.sink.audio) page.sink.audio.muted = !page.sink.audio.muted
                }
                Slider {
                    Layout.fillWidth: true
                    icon: page.source && page.source.audio && page.source.audio.muted ? "mic_off" : "mic"
                    muted: !!(page.source && page.source.audio && page.source.audio.muted)
                    value: page.source && page.source.audio ? page.source.audio.volume : 0
                    onMoved: v => { if (page.source && page.source.audio) page.source.audio.volume = v; }
                    onIconClicked: if (page.source && page.source.audio) page.source.audio.muted = !page.source.audio.muted
                }
                Slider {
                    Layout.fillWidth: true
                    visible: page.brightness >= 0
                    icon: "light_mode"
                    value: Math.max(0, page.brightness)
                    onMoved: v => { page.brightness = v; Quickshell.execDetached(["brightnessctl", "-c", "backlight", "set", Math.max(1, Math.round(v * 100)) + "%"]); }
                }
            }
        }

        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 8
            columnSpacing: 8
            Tile {
                icon: "wifi"; title: "Wi-Fi"; on: page.wifiOn
                onClicked: { page.wifiOn = !page.wifiOn; Quickshell.execDetached(["nmcli", "radio", "wifi", page.wifiOn ? "on" : "off"]); }
            }
            Tile {
                icon: "bluetooth"; title: "Bluetooth"; on: !!(page.bt && page.bt.enabled)
                state: !page.bt ? "No adapter" : ""
                onClicked: if (page.bt) page.bt.enabled = !page.bt.enabled
            }
            Tile {
                icon: "nightlight"; title: "Night light"; on: page.nightOn
                onClicked: {
                    page.nightOn = !page.nightOn;
                    Quickshell.execDetached(page.nightOn ? ["sh", "-c", "setsid -f wlsunset -t 4000 -T 6500 >/dev/null 2>&1"] : ["pkill", "-x", "wlsunset"]);
                }
            }
            Tile {
                icon: "coffee"; title: "Stay awake"; on: page.awake
                onClicked: page.awake = !page.awake
            }
            Tile {
                icon: "airplanemode_active"; title: "Airplane mode"
                on: !page.wifiOn && !(page.bt && page.bt.enabled)
                onClicked: {
                    const goOff = page.wifiOn || (page.bt && page.bt.enabled);
                    page.wifiOn = !goOff;
                    Quickshell.execDetached(["nmcli", "radio", "wifi", goOff ? "off" : "on"]);
                    if (page.bt) page.bt.enabled = !goOff;
                }
            }
            Tile {
                icon: "keyboard"; title: "Keyboard"; state: Niri.layoutName !== "" ? Niri.layoutName : "—"
                onClicked: Niri.action(["switch-layout", "next"])
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            PowerButton { icon: "lock"; onClicked: { HubState.close(); LockState.lock(); } }
            PowerButton { icon: "bedtime"; onClicked: { HubState.close(); Quickshell.execDetached(["loginctl", "suspend"]); } }
            PowerButton { icon: "logout"; onClicked: Niri.action(["quit"]) }
            PowerButton { icon: "restart_alt"; onClicked: Quickshell.execDetached(["loginctl", "reboot"]) }
            PowerButton { icon: "power_settings_new"; color: Qt.alpha(Theme.danger, 0.22); onClicked: Quickshell.execDetached(["loginctl", "poweroff"]) }
        }
    }
}
