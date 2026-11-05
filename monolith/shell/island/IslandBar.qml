import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// The island's bar row: what shows while it's collapsed (and stays on top while it's open).
// Left: control center, search, now playing, the clock, workspaces. Right: what's running
// (recording / timer / update), tray, stats, notifications, network, sound, power.
// Every part opens its page in the island.
Item {
    id: bar
    property string screenName: ""
    property var trayWindow: null                       // the window tray menus open from
    implicitWidth: left.width + mid.width + right.width + 2 * gap + 2 * Theme.islandPad
    implicitHeight: Theme.islandH
    readonly property real gap: 14
    function shows(part) { return Store.get("status.show." + part, true) !== false; }
    function open(p) { HubState.toggle(p, bar.screenName); }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // a module: a hover pill with a ripple
    component Mod: Pressable {
        id: m
        default property alias content: inner.data
        property real pad: 9
        height: Theme.islandH - 10
        width: inner.implicitWidth + 2 * pad
        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
        color: hovered ? Theme.containerHigh : "transparent"
        Row { id: inner; x: m.pad; anchors.verticalCenter: parent.verticalCenter; spacing: 6 }
    }
    // a round icon module
    component Glyph: Mod {
        property string icon: ""
        property bool on: false
        property color tint: Theme.text
        pad: 7
        Icon { name: parent.parent.icon; size: 18; filled: parent.parent.on; color: parent.parent.tint; anchors.verticalCenter: parent.verticalCenter }
    }

    Row {
        id: left
        x: Theme.islandPad
        height: parent.height
        spacing: 2

        // the control center: a filled accent bubble, the island's anchor
        Pressable {
            width: 30; height: 30
            anchors.verticalCenter: parent.verticalCenter
            color: HubState.open && HubState.page === "quick" ? Theme.accent : Theme.accentContainer
            ink: Theme.onAccent
            radius: 15
            onClicked: bar.open("quick")
            Icon { anchors.centerIn: parent; name: "page_info"; size: 18; filled: true; color: HubState.open && HubState.page === "quick" ? Theme.onAccent : Theme.onAccentContainer }
        }
        Glyph { icon: "search"; onClicked: bar.open("search") }

        // the clock: the time, with the weekday and date stacked beside it
        Mod {
            onClicked: bar.open("calendar")
            Text {
                text: Qt.formatTime(clock.date, "HH:mm")
                color: Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 16; font.weight: Font.Bold
                anchors.verticalCenter: parent.verticalCenter
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: -2
                Text { text: Qt.formatDate(clock.date, "dddd"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1; font.weight: Font.Medium }
                Text { text: Qt.formatDate(clock.date, "d MMM"); color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Theme.sizeTiny + 1 }
            }
            Icon {
                visible: Weather.ready && bar.shows("weather")
                name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : ""
                size: 16; color: Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                visible: Weather.ready && bar.shows("weather")
                text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""
                font.pixelSize: Theme.sizeSmall
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // workspaces on this screen: the active one a long accent pill
        Item {
            width: ws.width + 14
            height: parent.height
            Row {
                id: ws
                anchors.centerIn: parent
                spacing: 5
                Repeater {
                    model: Niri.workspacesOn(bar.screenName)
                    Rectangle {
                        required property var modelData
                        readonly property bool active: modelData.is_active
                        readonly property bool busy: Niri.workspaceHasWindows(modelData.id)
                        width: active ? 26 : 9
                        height: 9
                        radius: 4.5
                        anchors.verticalCenter: parent.verticalCenter
                        color: active ? Theme.accent : (busy ? Theme.subtext : Theme.control)
                        Behavior on width { SpringAnimation { spring: Theme.springK; damping: Theme.springDamp; epsilon: 0.3 } }
                        Behavior on color { ColorAnimation { duration: 200 } }
                        MouseArea { anchors.fill: parent; anchors.margins: -4; cursorShape: Qt.PointingHandCursor; onClicked: Niri.focusWorkspace(parent.modelData.idx) }
                    }
                }
            }
        }
    }

    // ── middle: now playing (the album art spins while it plays), or the window title ──
    Item {
        id: mid
        x: left.x + left.width + bar.gap
        width: midRow.visible ? midRow.width : 0
        height: parent.height
        Mod {
            id: midRow
            visible: bar.player !== null && bar.shows("media") || (Niri.focusedTitle !== "" && bar.shows("title"))
            readonly property bool music: bar.player !== null && bar.shows("media")
            onClicked: bar.open(music ? "media" : "windows")
            Rectangle {
                visible: midRow.music
                width: 22; height: 22; radius: 11
                color: Theme.control
                clip: true
                anchors.verticalCenter: parent.verticalCenter
                Image {
                    anchors.fill: parent
                    source: bar.player ? (bar.player.trackArtUrl || "") : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize: Qt.size(64, 64)
                    RotationAnimation on rotation { from: 0; to: 360; duration: 9000; loops: Animation.Infinite; running: midRow.music }
                }
            }
            Icon { visible: !midRow.music; name: "select_window"; size: 16; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
            Label {
                text: midRow.music ? bar.player.trackTitle : Niri.focusedTitle
                font.pixelSize: Theme.sizeSmall
                muted: !midRow.music
                width: Math.min(implicitWidth, 200)
                anchors.verticalCenter: parent.verticalCenter
            }
        }
    }

    Row {
        id: right
        x: mid.x + mid.width + (mid.width > 0 ? bar.gap : 0)
        height: parent.height
        spacing: 2

        // what's running: a recording (click stops it), the timer, an update
        Mod {
            id: live
            readonly property string mode: Tasks.recording ? "rec" : (Tasks.total > 0 && Tasks.remaining > 0 ? "timer" : (Updates.available > 0 && bar.shows("updates") ? "update" : ""))
            visible: mode !== ""
            color: mode === "rec" ? Qt.alpha(Theme.danger, hovered ? 0.32 : 0.2) : (hovered ? Theme.selected : Theme.containerHigh)
            onClicked: {
                if (mode === "rec") Tasks.stopRecording();
                else if (mode === "timer") bar.open("tools");
                else HubState.openSettings("about", bar.screenName);
            }
            Rectangle {
                visible: live.mode === "rec"
                width: 9; height: 9; radius: 4.5; color: Theme.danger
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity { running: live.mode === "rec"; loops: Animation.Infinite; NumberAnimation { to: 0.3; duration: 700 } NumberAnimation { to: 1; duration: 700 } }
            }
            Icon { visible: live.mode !== "rec"; name: live.mode === "timer" ? "timer" : "upgrade"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Label {
                text: live.mode === "rec" ? Tasks.fmt(Tasks.recSeconds) : (live.mode === "timer" ? Tasks.fmt(Tasks.remaining) : String(Updates.available))
                font.pixelSize: Theme.sizeSmall; strong: true
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        Repeater {
            model: bar.shows("tray") ? SystemTray.items : []
            Pressable {
                required property var modelData
                width: 28; height: 28
                anchors.verticalCenter: parent.verticalCenter
                color: hovered ? Theme.containerHigh : "transparent"
                Image { anchors.centerIn: parent; width: 16; height: 16; source: modelData.icon; sourceSize: Qt.size(32, 32) }
                onClicked: modelData.activate()
                onRightClicked: { if (bar.trayWindow) { const p = mapToItem(null, 0, height); modelData.display(bar.trayWindow, p.x, p.y + 4); } }
            }
        }

        Mod {
            visible: bar.shows("stats")
            onClicked: { HubState.ccTab = "monitor"; bar.open("quick"); }
            Repeater {
                model: [["memory", Math.round(Stats.cpu * 100) + "%"], ["thermostat", Math.round(Stats.temp) + "°"]]
                Row {
                    required property var modelData
                    spacing: 3
                    anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                    Icon { name: modelData[0]; size: 15; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: modelData[1]; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }

        Mod {
            pad: 7
            onClicked: bar.open("notifications")
            Icon {
                name: Notifs.dnd ? "notifications_paused" : (Notifs.list.length > 0 ? "notifications_unread" : "notifications")
                size: 18; filled: Notifs.list.length > 0
                color: Notifs.list.length > 0 && !Notifs.dnd ? Theme.accent : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
            Label { visible: Notifs.list.length > 0; text: Notifs.list.length; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
        }
        Glyph { icon: bar.netIcon; on: true; onClicked: bar.open("network") }
        Mod {
            pad: 7
            onClicked: bar.open("sound")
            Icon {
                name: bar.muted || bar.volume === 0 ? "volume_off" : (bar.volume < 0.4 ? "volume_down" : "volume_up")
                size: 18; filled: true; color: bar.muted ? Theme.subtext : Theme.text
                anchors.verticalCenter: parent.verticalCenter
            }
            Label { text: Math.round(bar.volume * 100); font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
        }
        Glyph { icon: "power_settings_new"; tint: Theme.danger; onClicked: { HubState.ccTab = "controls"; bar.open("quick"); } }
    }

    // the connection, for the network glyph (wired wins over Wi-Fi)
    property string netIcon: "signal_disconnected"
    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                bar.netIcon = l.some(x => x === "ethernet:connected") ? "lan" : (l.some(x => x === "wifi:connected") ? "wifi" : "signal_disconnected");
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: netProc.running = true }
}
