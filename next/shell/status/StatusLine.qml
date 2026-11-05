import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pipewire
import Quickshell.Services.SystemTray
import Quickshell.Services.Mpris
import Quickshell.Io
import "../core"
import "../ui"

// The status line: one row of text and glyphs across the top of a screen, on a scrim that
// fades into the wallpaper (no bar behind it). Each part opens its hub page.
PanelWindow {
    id: line
    required property var modelData
    screen: modelData

    WlrLayershell.namespace: "monolith-status"
    WlrLayershell.layer: WlrLayer.Top
    // top or bottom of the screen (Settings → Status line)
    readonly property bool atBottom: Store.get("status.position", "top") === "bottom"
    anchors { top: !atBottom; bottom: atBottom; left: true; right: true }
    implicitHeight: 64
    // auto-hide: no reserved space; the line slides away and comes back when the pointer
    // touches the screen edge (or a hub page is open)
    readonly property bool autohide: Store.get("status.autohide", false) === true
    readonly property bool tucked: autohide && !edge.containsMouse && !rowHover.hovered && !HubState.open
    exclusiveZone: autohide ? 0 : rowH + 6
    color: "transparent"
    // only the row takes the mouse; the rest of the scrim lets clicks through
    mask: Region { item: tucked ? edge : row }
    function shows(part) { return Store.get("status.show." + part, true) !== false; }

    readonly property real rowH: 34

    MouseArea {
        id: edge
        anchors.left: parent.left; anchors.right: parent.right
        y: line.atBottom ? parent.height - 3 : 0
        height: 3
        hoverEnabled: true
    }
    HoverHandler { id: rowHover }

    // the scrim: the card colour at the edge, gone by the bottom of the window
    Rectangle {
        anchors.fill: parent
        rotation: line.atBottom ? 180 : 0
        opacity: line.tucked ? 0 : 1
        Behavior on opacity { NumberAnimation { duration: 250 } }
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.alpha(Theme.card, 0.82) }
            GradientStop { position: 0.55; color: Qt.alpha(Theme.card, 0.35) }
            GradientStop { position: 1.0; color: "transparent" }
        }
    }

    PwObjectTracker { objects: [Pipewire.defaultAudioSink] }
    readonly property var sink: Pipewire.defaultAudioSink
    readonly property real volume: sink && sink.audio ? sink.audio.volume : 0
    readonly property bool muted: sink && sink.audio ? sink.audio.muted : false
    readonly property var player: Mpris.players.values.length > 0 ? Mpris.players.values.find(p => p.isPlaying) || Mpris.players.values[0] : null

    // a hover pill with a ripple around a part of the line
    component Chip: Pressable {
        id: chip
        default property alias content: inner.data
        property real pad: 10
        readonly property real contentW: inner.implicitWidth
        height: line.rowH - 6
        width: inner.childrenRect.width + pad * 2
        color: hovered ? Theme.containerHigh : "transparent"
        radius: Theme.corner(height)
        Row {
            id: inner
            x: chip.pad
            anchors.verticalCenter: parent.verticalCenter
            spacing: 6
        }
    }

    Item {
        id: row
        x: 10
        y: line.atBottom ? parent.height - height - 4 : 4
        width: parent.width - 20
        height: line.rowH
        opacity: line.tucked ? 0 : 1
        transform: Translate {
            y: line.tucked ? (line.atBottom ? 1 : -1) * (line.rowH + 8) : 0
            Behavior on y { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
        }
        Behavior on opacity { NumberAnimation { duration: 200 } }

        // ── left: time, workspaces ──
        Row {
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            spacing: 4

            Chip {
                onClicked: HubState.toggle("calendar", line.screen.name)
                Label {
                    text: Qt.formatTime(clock.date, "HH:mm")
                    font.pixelSize: Theme.sizeBody + 1
                    strong: true
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    text: Qt.formatDate(clock.date, "ddd d MMM")
                    muted: true
                    font.pixelSize: Theme.sizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
                Icon {
                    visible: Weather.ready && line.shows("weather")
                    name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : ""
                    size: 16
                    color: Theme.accent
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label {
                    visible: Weather.ready && line.shows("weather")
                    text: Weather.ready ? Math.round(Weather.current.temp) + "°" : ""
                    font.pixelSize: Theme.sizeSmall
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            // workspaces on this screen: the active one a short accent bar, ones with
            // windows a dot, empty ones a faint dot
            Item {
                width: wsRow.width + 16
                height: line.rowH - 6
                anchors.verticalCenter: parent.verticalCenter
                Row {
                    id: wsRow
                    anchors.centerIn: parent
                    spacing: 6
                    Repeater {
                        model: Niri.workspacesOn(line.screen.name)
                        Item {
                            required property var modelData
                            readonly property bool active: modelData.is_active
                            readonly property bool busy: Niri.workspaceHasWindows(modelData.id)
                            width: active ? 22 : 8
                            height: 18
                            Behavior on width { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
                            Rectangle {
                                anchors.centerIn: parent
                                width: parent.width
                                height: parent.active ? 8 : (parent.busy ? 7 : 5)
                                radius: height / 2
                                color: parent.active ? Theme.accent : (parent.busy ? Theme.text : Theme.faint)
                                opacity: parent.active || parent.busy ? 1 : 0.7
                                Behavior on color { ColorAnimation { duration: 220 } }
                            }
                            MouseArea {
                                anchors.fill: parent
                                anchors.margins: -3
                                cursorShape: Qt.PointingHandCursor
                                onClicked: Niri.focusWorkspace(parent.modelData.idx)
                            }
                        }
                    }
                }
            }
        }

        // ── middle: the island. Normally the focused window (opens Search); it grows into a
        // live chip while something runs: a recording (click stops it) or the timer ──
        Chip {
            id: island
            anchors.centerIn: parent
            readonly property string mode: Tasks.recording ? "rec" : (Tasks.total > 0 && Tasks.remaining > 0 ? "timer" : (Updates.available > 0 && line.shows("updates") ? "update" : "title"))
            visible: mode !== "title" || (Niri.focusedTitle !== "" && line.shows("title"))
            width: mode === "title" ? Math.min(implicitTitle.implicitWidth + 24 + 26, row.width * 0.34) : contentW + pad * 2
            color: mode === "rec" ? Qt.alpha(Theme.danger, hovered ? 0.3 : 0.2) : (mode === "title" ? (hovered ? Theme.containerHigh : "transparent") : (hovered ? Theme.selected : Theme.containerHigh))
            Behavior on width { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
            onClicked: {
                if (mode === "rec") Tasks.stopRecording();
                else if (mode === "timer") HubState.toggle("tools", line.screen.name);
                else if (mode === "update") HubState.openSettings("about", line.screen.name);
                else HubState.toggle("search", line.screen.name);
            }
            // recording: a pulsing red dot and the time
            Rectangle {
                visible: island.mode === "rec"
                width: 10; height: 10; radius: 5
                color: Theme.danger
                anchors.verticalCenter: parent.verticalCenter
                SequentialAnimation on opacity {
                    running: island.mode === "rec"; loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 700 }
                    NumberAnimation { to: 1; duration: 700 }
                }
            }
            Icon {
                visible: island.mode !== "rec"
                name: island.mode === "timer" ? "timer" : (island.mode === "update" ? "upgrade" : "search")
                size: 16
                color: island.mode === "title" ? Theme.subtext : Theme.accent
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                visible: island.mode !== "title"
                text: island.mode === "rec" ? "Recording  " + Tasks.fmt(Tasks.recSeconds) + "   ·   stop"
                    : (island.mode === "timer" ? Tasks.fmt(Tasks.remaining) + (Tasks.timing ? "" : "  (paused)")
                    : (Updates.available + (Updates.available === 1 ? " update" : " updates")))
                font.pixelSize: Theme.sizeSmall
                strong: true
                anchors.verticalCenter: parent.verticalCenter
            }
            Label {
                id: implicitTitle
                visible: island.mode === "title"
                text: Niri.focusedTitle
                muted: true
                font.pixelSize: Theme.sizeSmall
                width: Math.min(implicitWidth, row.width * 0.34 - 50)
                anchors.verticalCenter: parent.verticalCenter
            }
        }

        // ── right: now playing, stats, tray, sound ──
        Row {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            spacing: 2

            Chip {
                visible: line.shows("media") && !!line.player && (line.player.trackTitle || "") !== ""
                onClicked: HubState.toggle("media", line.screen.name)
                Icon { name: line.player && line.player.isPlaying ? "graphic_eq" : "music_note"; size: 16; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    text: line.player ? line.player.trackTitle : ""
                    font.pixelSize: Theme.sizeSmall
                    width: Math.min(implicitWidth, 180)
                    anchors.verticalCenter: parent.verticalCenter
                }
            }

            Chip {
                visible: line.shows("stats")
                onClicked: HubState.toggle("quick", line.screen.name)
                Repeater {
                    model: [
                        { icon: "memory", value: Math.round(Stats.cpu * 100) + "%" },
                        { icon: "data_usage", value: Math.round(Stats.mem * 100) + "%" },
                        { icon: "thermostat", value: Math.round(Stats.temp) + "°" }
                    ]
                    Row {
                        required property var modelData
                        spacing: 3
                        anchors.verticalCenter: parent ? parent.verticalCenter : undefined
                        Icon { name: modelData.icon; size: 15; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                        Label { text: modelData.value; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
                    }
                }
            }

            Repeater {
                model: line.shows("tray") ? SystemTray.items : []
                Pressable {
                    required property var modelData
                    width: line.rowH - 6
                    height: width
                    anchors.verticalCenter: parent.verticalCenter
                    color: hovered ? Theme.containerHigh : "transparent"
                    Image {
                        anchors.centerIn: parent
                        width: 16
                        height: 16
                        source: modelData.icon
                        sourceSize: Qt.size(32, 32)
                        smooth: true
                    }
                    onClicked: modelData.activate()
                    onRightClicked: {
                        const p = mapToItem(null, 0, height);
                        modelData.display(line, p.x, p.y + 4);
                    }
                }
            }

            Chip {
                onClicked: HubState.toggle("network", line.screen.name)
                Icon { name: line.netIcon; size: 17; filled: true; anchors.verticalCenter: parent.verticalCenter }
            }

            Chip {
                onClicked: HubState.toggle("notifications", line.screen.name)
                Icon {
                    name: Notifs.dnd ? "notifications_paused" : (Notifs.list.length > 0 ? "notifications_unread" : "notifications")
                    size: 17
                    filled: Notifs.list.length > 0
                    color: Notifs.list.length > 0 && !Notifs.dnd ? Theme.accent : Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label { visible: Notifs.list.length > 0; text: Notifs.list.length; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
            }

            Chip {
                onClicked: HubState.toggle("sound", line.screen.name)
                Icon {
                    name: line.muted || line.volume === 0 ? "volume_off" : (line.volume < 0.4 ? "volume_down" : "volume_up")
                    size: 17
                    filled: true
                    color: line.muted ? Theme.subtext : Theme.text
                    anchors.verticalCenter: parent.verticalCenter
                }
                Label { text: Math.round(line.volume * 100) + "%"; font.pixelSize: Theme.sizeSmall; anchors.verticalCenter: parent.verticalCenter }
            }
        }
    }

    SystemClock { id: clock; precision: SystemClock.Minutes }

    // the connection, for the network glyph (wired wins over Wi-Fi)
    property string netIcon: "signal_disconnected"
    Process {
        id: netProc
        command: ["nmcli", "-t", "-f", "TYPE,STATE", "dev"]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.split("\n");
                line.netIcon = l.some(x => x === "ethernet:connected") ? "lan" : (l.some(x => x === "wifi:connected") ? "wifi" : "signal_disconnected");
            }
        }
    }
    Timer { interval: 10000; running: true; repeat: true; triggeredOnStart: true; onTriggered: netProc.running = true }
}
