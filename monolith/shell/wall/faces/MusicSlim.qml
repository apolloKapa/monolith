import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../core"
import "../../ui"

// Music, controls: a slim player. On top the seek bar (a wave while it plays) between the time
// played and the time left; under it repeat (off, the playlist, this track), previous, play or
// pause, next, and the volume (the player's own when it has one, else the speakers'): click the
// speaker to mute, scroll on it or drag the bar that opens beside it.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property bool active: !!p && p.trackTitle !== ""
    PlayPosition { id: pp; player: f.p; active: f.live && f.visible }
    function mmss(t) { t = Math.max(0, Math.floor(t || 0)); return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0"); }

    // sizes follow the widget's height
    readonly property real pad: Math.max(8, Math.min(20, height * 0.12))
    readonly property real btn: Math.max(24, Math.min(64, height * 0.4))
    readonly property real timeSize: Math.max(9, Math.min(18, height * 0.14))

    // repeat: off → the playlist → this track → off
    readonly property bool canLoop: !!p && p.loopSupported
    function cycleLoop() {
        if (!canLoop) return;
        p.loopState = p.loopState === MprisLoopState.None ? MprisLoopState.Playlist
            : (p.loopState === MprisLoopState.Playlist ? MprisLoopState.Track : MprisLoopState.None);
    }

    // volume
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }
    readonly property var sink: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio : null
    readonly property bool ownVolume: !!p && p.volumeSupported
    readonly property real volume: ownVolume ? p.volume : (sink ? (sink.muted ? 0 : sink.volume) : 0)
    property real lastVolume: 0.5
    property bool volOpen: false
    function setVolume(v) {
        v = Math.max(0, Math.min(1, v));
        if (ownVolume) p.volume = v;
        else if (sink) { sink.muted = false; sink.volume = v; }
        volOpen = true; volClose.restart();
    }
    function toggleMute() {
        if (volume > 0.001) { lastVolume = volume; setVolume(0); }
        else setVolume(lastVolume > 0.01 ? lastVolume : 0.5);
    }
    Timer { id: volClose; interval: 2500; onTriggered: if (!volArea.containsMouse && !volDrag.pressed) f.volOpen = false }

    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(Math.min(f.height, 120), 16) }

    Column {
        anchors.fill: parent
        anchors.leftMargin: f.pad * 1.3; anchors.rightMargin: f.pad * 1.3
        anchors.topMargin: f.pad * 0.8; anchors.bottomMargin: f.pad * 0.6
        spacing: Math.max(2, f.pad * 0.3)

        // the time played, the seek bar, the time left
        Row {
            id: seekRow
            width: parent.width
            height: Math.max(16, f.timeSize * 1.4)
            spacing: Math.max(6, f.pad * 0.6)
            Text {
                id: played
                anchors.verticalCenter: parent.verticalCenter
                text: f.active ? f.mmss(pp.shown) : "-:--"
                color: f.subC; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.timeSize
            }
            WavySeek {
                anchors.verticalCenter: parent.verticalCenter
                width: seekRow.width - played.width - left.width - 2 * seekRow.spacing
                height: seekRow.height
                live: f.live
                color: f.accentC
                value: f.active ? pp.shown : 0
                to: f.active && f.p.length > 0 ? f.p.length : 1
                playing: f.active && f.p.isPlaying
                onMoved: v => { if (f.p && f.p.canSeek) { f.p.position = v; pp.sync(); } }
            }
            Text {
                id: left
                anchors.verticalCenter: parent.verticalCenter
                text: f.active && f.p.length > 0 ? "-" + f.mmss(f.p.length - pp.shown) : "-:--"
                color: f.subC; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.timeSize
            }
        }

        // the buttons
        Item {
            width: parent.width
            height: parent.height - seekRow.height - parent.spacing

            // repeat, on the left
            Pressable {
                anchors.left: parent.left; anchors.verticalCenter: parent.verticalCenter
                width: f.btn * 0.8; height: width
                radius: width / 2
                enabledInput: f.canLoop
                opacity: f.canLoop ? 1 : 0.4
                color: f.p && f.p.loopState !== MprisLoopState.None ? Qt.alpha(f.accentC, 0.22) : (hovered ? Qt.alpha(Theme.text, 0.1) : "transparent")
                onClicked: f.cycleLoop()
                Icon {
                    anchors.centerIn: parent
                    name: f.p && f.p.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                    size: Math.round(f.btn * 0.36)
                    color: f.p && f.p.loopState !== MprisLoopState.None ? f.accentC : f.mainC
                }
            }

            // previous, play / pause, next, in the middle
            Row {
                anchors.centerIn: parent
                spacing: Math.max(4, f.pad * 0.5)
                Repeater {
                    model: [["skip_previous", 0], [f.p && f.p.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
                    Pressable {
                        required property var modelData
                        readonly property bool main: modelData[1] === 1
                        anchors.verticalCenter: parent.verticalCenter
                        width: main ? f.btn * 1.25 : f.btn * 0.9; height: main ? f.btn : f.btn * 0.9
                        radius: height / 2
                        enabledInput: !!f.p
                        color: main ? f.accentC : (hovered ? Qt.alpha(Theme.text, 0.1) : "transparent")
                        ink: main ? Theme.onAccent : Theme.text
                        onClicked: {
                            if (!f.p) return;
                            if (modelData[1] === 0) f.p.previous();
                            else if (modelData[1] === 1) f.p.togglePlaying();
                            else f.p.next();
                        }
                        Icon {
                            anchors.centerIn: parent
                            name: parent.modelData[0]; filled: true
                            size: Math.round(f.btn * (parent.main ? 0.5 : 0.42))
                            color: parent.main ? Theme.onAccent : f.mainC
                        }
                    }
                }
            }

            // the volume, on the right: the speaker, and a bar that opens beside it
            Item {
                anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                height: f.btn * 0.8
                width: height + (f.volOpen ? volBar.width + 8 : 0)
                Behavior on width { NumberAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                clip: true
                MouseArea {
                    id: volArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onWheel: wheel => f.setVolume(f.volume + (wheel.angleDelta.y > 0 ? 0.05 : -0.05))
                    onContainsMouseChanged: if (containsMouse) { f.volOpen = true; volClose.stop(); } else volClose.restart()
                }
                Item {
                    id: volBar
                    anchors.right: spk.left; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(60, f.width * 0.22); height: 6
                    Rectangle { anchors.fill: parent; radius: 3; color: Qt.alpha(Theme.text, 0.15) }
                    Rectangle { width: parent.width * f.volume; height: parent.height; radius: 3; color: f.accentC }
                    MouseArea {
                        id: volDrag
                        anchors.fill: parent; anchors.margins: -8
                        onPressed: mouse => f.setVolume((mouse.x - 8) / volBar.width)
                        onPositionChanged: mouse => { if (pressed) f.setVolume((mouse.x - 8) / volBar.width); }
                    }
                }
                Pressable {
                    id: spk
                    anchors.right: parent.right; anchors.verticalCenter: parent.verticalCenter
                    width: parent.height; height: width
                    radius: width / 2
                    color: hovered ? Qt.alpha(Theme.text, 0.1) : "transparent"
                    onClicked: f.toggleMute()
                    Icon {
                        anchors.centerIn: parent
                        name: f.volume < 0.001 ? "volume_off" : (f.volume < 0.5 ? "volume_down" : "volume_up")
                        size: Math.round(f.btn * 0.36)
                        color: f.mainC
                    }
                }
            }
        }
    }
}
