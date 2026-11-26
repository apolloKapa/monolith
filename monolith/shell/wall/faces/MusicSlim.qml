import QtQuick
import Quickshell.Services.Mpris
import Quickshell.Services.Pipewire
import "../../core"
import "../../ui"

// Music, controls: a slim player on glass. Along the top, the time played, the seek bar (a wave
// while the song plays) and the time still to go. Underneath: repeat on the left (off, the whole
// list, this song), previous / play-pause / next in the middle, and the volume on the right, the
// player's own if it has one, otherwise the speakers'. Click the speaker to mute and unmute;
// hover or scroll on it and a slider slides out beside it.
FaceBase {
    id: face
    readonly property var mp: face.player
    readonly property bool hasTrack: !!mp && mp.trackTitle !== ""
    PlayPosition { id: clock; player: face.mp; active: face.live && face.visible }
    // seconds as m:ss
    function stamp(sec) {
        const t = Math.max(0, Math.floor(sec || 0));
        return Math.floor(t / 60) + ":" + (t % 60 < 10 ? "0" : "") + (t % 60);
    }

    // everything is sized from the widget's height
    readonly property real gutter: Math.max(8, Math.min(20, height * 0.12))
    readonly property real button: Math.max(24, Math.min(64, height * 0.4))
    readonly property real timePx: Math.max(9, Math.min(18, height * 0.14))
    readonly property color hoverInk: Qt.alpha(Theme.text, 0.1)

    // repeat goes round: off, the list, the song, off again
    readonly property bool repeats: !!mp && mp.loopSupported
    readonly property bool repeating: !!mp && mp.loopState !== MprisLoopState.None
    readonly property var repeatAfter: ({ [MprisLoopState.None]: MprisLoopState.Playlist, [MprisLoopState.Playlist]: MprisLoopState.Track, [MprisLoopState.Track]: MprisLoopState.None })
    function stepRepeat() { if (repeats) mp.loopState = repeatAfter[mp.loopState]; }

    // the volume
    PwObjectTracker { objects: Pipewire.defaultAudioSink ? [Pipewire.defaultAudioSink] : [] }
    QtObject {
        id: loudness
        readonly property var speakers: Pipewire.defaultAudioSink && Pipewire.defaultAudioSink.audio ? Pipewire.defaultAudioSink.audio : null
        readonly property bool playerOwn: !!face.mp && face.mp.volumeSupported
        readonly property real level: playerOwn ? face.mp.volume : (speakers ? (speakers.muted ? 0 : speakers.volume) : 0)
        property real beforeMute: 0.5
        property bool shown: false
        function put(v) {
            const x = v < 0 ? 0 : (v > 1 ? 1 : v);
            if (playerOwn) face.mp.volume = x;
            else if (speakers) { speakers.muted = false; speakers.volume = x; }
            shown = true;
            hideSlider.restart();
        }
        function flipMute() {
            if (level > 0.001) { beforeMute = level; put(0); }
            else put(beforeMute > 0.01 ? beforeMute : 0.5);
        }
    }
    Timer { id: hideSlider; interval: 2500; onTriggered: if (!volumeHover.containsMouse && !sliderDrag.pressed) loudness.shown = false }

    // a round button with an icon; `lead` is the big accent-filled play button
    component Disc: Pressable {
        id: disc
        property string glyph: ""
        property bool lead: false
        property real glyphPart: 0.42
        property bool lit: false
        property bool solid: true
        radius: height / 2
        color: lead ? face.accentC : (lit ? Qt.alpha(face.accentC, 0.22) : (hovered ? face.hoverInk : "transparent"))
        Icon {
            anchors.centerIn: parent
            name: disc.glyph
            filled: disc.solid
            size: Math.round(face.button * disc.glyphPart)
            color: disc.lead ? Theme.onAccent : (disc.lit ? face.accentC : face.mainC)
        }
    }
    component Stamp: Text {
        anchors.verticalCenter: parent.verticalCenter
        renderType: Text.CurveRendering
        color: face.subC
        font.family: Theme.fontFamily
        font.weight: Font.Bold
        font.pixelSize: face.timePx
    }

    Glass { anchors.fill: parent; ctx: face.ctx; radius: Theme.corner(Math.min(face.height, 120), 16) }

    Column {
        anchors.fill: parent
        anchors.leftMargin: face.gutter * 1.3
        anchors.rightMargin: face.gutter * 1.3
        anchors.topMargin: face.gutter * 0.8
        anchors.bottomMargin: face.gutter * 0.6
        spacing: Math.max(2, face.gutter * 0.3)

        Row {
            id: timeline
            width: parent.width
            height: Math.max(16, face.timePx * 1.4)
            spacing: Math.max(6, face.gutter * 0.6)
            Stamp { id: gone; text: face.hasTrack ? face.stamp(clock.shown) : "-:--" }
            WavySeek {
                anchors.verticalCenter: parent.verticalCenter
                width: timeline.width - gone.width - toGo.width - 2 * timeline.spacing
                height: timeline.height
                live: face.live
                color: face.accentC
                value: face.hasTrack ? clock.shown : 0
                to: face.hasTrack && face.mp.length > 0 ? face.mp.length : 1
                playing: face.hasTrack && face.mp.isPlaying
                onMoved: v => { if (face.mp && face.mp.canSeek) { face.mp.position = v; clock.sync(); } }
            }
            Stamp { id: toGo; text: face.hasTrack && face.mp.length > 0 ? "-" + face.stamp(face.mp.length - clock.shown) : "-:--" }
        }

        Item {
            width: parent.width
            height: parent.height - timeline.height - parent.spacing

            Disc {
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
                width: face.button * 0.8
                height: width
                glyph: face.mp && face.mp.loopState === MprisLoopState.Track ? "repeat_one" : "repeat"
                glyphPart: 0.36
                solid: false
                lit: face.repeating
                enabledInput: face.repeats
                opacity: face.repeats ? 1 : 0.4
                onClicked: face.stepRepeat()
            }

            Row {
                anchors.centerIn: parent
                spacing: Math.max(4, face.gutter * 0.5)
                Disc {
                    anchors.verticalCenter: parent.verticalCenter
                    width: face.button * 0.9; height: width
                    glyph: "skip_previous"
                    enabledInput: !!face.mp
                    ink: Theme.text
                    onClicked: if (face.mp) face.mp.previous()
                }
                Disc {
                    anchors.verticalCenter: parent.verticalCenter
                    width: face.button * 1.25; height: face.button
                    lead: true
                    glyph: face.mp && face.mp.isPlaying ? "pause" : "play_arrow"
                    glyphPart: 0.5
                    enabledInput: !!face.mp
                    ink: Theme.onAccent
                    onClicked: if (face.mp) face.mp.togglePlaying()
                }
                Disc {
                    anchors.verticalCenter: parent.verticalCenter
                    width: face.button * 0.9; height: width
                    glyph: "skip_next"
                    enabledInput: !!face.mp
                    ink: Theme.text
                    onClicked: if (face.mp) face.mp.next()
                }
            }

            // the speaker, with its slider sliding out to the left of it
            Item {
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                height: face.button * 0.8
                width: height + (loudness.shown ? slider.width + 8 : 0)
                clip: true
                Behavior on width { NumberAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
                MouseArea {
                    id: volumeHover
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    onWheel: e => loudness.put(loudness.level + (e.angleDelta.y > 0 ? 0.05 : -0.05))
                    onContainsMouseChanged: { if (containsMouse) { loudness.shown = true; hideSlider.stop(); } else hideSlider.restart(); }
                }
                Item {
                    id: slider
                    anchors.right: speaker.left
                    anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(60, face.width * 0.22)
                    height: 6
                    WavyBar { visible: Theme.wavy; anchors.fill: parent; to: loudness.level; color: face.accentC; trackColor: Qt.alpha(Theme.text, 0.2) }
                    Rectangle { visible: !Theme.wavy; anchors.fill: parent; radius: Theme.chamfer ? 0 : 3; color: Qt.alpha(Theme.text, 0.15) }
                    Rectangle { visible: !Theme.wavy; width: parent.width * loudness.level; height: parent.height; radius: Theme.chamfer ? 0 : 3; color: face.accentC }
                    MouseArea {
                        id: sliderDrag
                        anchors.fill: parent
                        anchors.margins: -8
                        onPressed: e => loudness.put((e.x - 8) / slider.width)
                        onPositionChanged: e => { if (pressed) loudness.put((e.x - 8) / slider.width); }
                    }
                }
                Disc {
                    id: speaker
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.height; height: width
                    glyph: loudness.level < 0.001 ? "volume_off" : (loudness.level < 0.5 ? "volume_down" : "volume_up")
                    glyphPart: 0.36
                    solid: false
                    onClicked: loudness.flipMute()
                }
            }
        }
    }
}
