import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../reusables/inputs"
import "../../../"

// A slim player: the seek bar with the time left on top; repeat, previous / play-pause / next and volume under it.
Item {
    id: root
    anchors.fill: parent

    property real minWidth: 200
    property real minHeight: 70
    property real maxWidth: 1400
    property real maxHeight: 260
    property real minAspect: 1.6
    property real maxAspect: 8.0

    // background: blurred wallpaper behind it, and how see-through the tint over it is
    // (backgroundOpacity -1 = the theme's element opacity)
    property bool bgBlur: true
    property real backgroundOpacity: -1
    readonly property real effectiveBgOpacity: backgroundOpacity < 0 ? ThemeBackend.elementOpacity : Math.max(0, Math.min(1, backgroundOpacity))

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

    // repeat: off -> whole playlist -> this track
    readonly property bool canLoop: player !== null && player.loopSupported && player.canControl
    readonly property int loopState: player ? player.loopState : MprisLoopState.None
    function cycleLoop() {
        if (!canLoop) return;
        if (player.loopState === MprisLoopState.None) player.loopState = MprisLoopState.Playlist;
        else if (player.loopState === MprisLoopState.Playlist) player.loopState = MprisLoopState.Track;
        else player.loopState = MprisLoopState.None;
    }

    // volume: the player's own when it has one, otherwise the system output
    readonly property bool usePlayerVolume: player !== null && player.volumeSupported && player.canControl
    readonly property var sinkAudio: Audio.defaultSink && Audio.defaultSink.audio ? Audio.defaultSink.audio : null
    readonly property real volume: usePlayerVolume ? player.volume : (sinkAudio ? (sinkAudio.muted ? 0 : sinkAudio.volume) : 0)
    property real volumeBeforeMute: 0.5
    property bool volExpanded: false
    function setVolume(v) {
        v = Math.max(0, Math.min(1, v));
        if (usePlayerVolume) player.volume = v;
        else if (sinkAudio) { sinkAudio.muted = false; sinkAudio.volume = v; }
        volExpanded = true;
        volCollapse.restart();
    }
    function toggleMute() {
        if (volume > 0.001) { volumeBeforeMute = volume; setVolume(0); }
        else setVolume(volumeBeforeMute > 0.01 ? volumeBeforeMute : 0.5);
    }
    Timer { id: volCollapse; interval: 2500; onTriggered: if (!volHover.hovered && !volSliderMa.pressed) root.volExpanded = false }

    readonly property real pad: Math.max(6, Math.min(18, height * 0.12))
    readonly property real btnSize: Math.max(22, Math.min(64, height * 0.42))
    readonly property real iconSize: Math.round(btnSize * 0.42)
    readonly property real timeSize: Math.max(9, Math.min(18, height * 0.15))

    function formatTime(sec) {
        sec = Math.max(0, Math.floor(sec || 0));
        let m = Math.floor(sec / 60), s = sec % 60;
        return m + ":" + (s < 10 ? "0" : "") + s;
    }

    Rectangle {
        id: bg
        anchors.fill: parent
        color: Qt.alpha(ThemeBackend.surface0, root.effectiveBgOpacity)
        radius: ThemeBackend.rad(Math.min(height / 2, ThemeBackend.borderRadius * 1.5))

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: bg.radius
            force: root.bgBlur
            visible: root.bgBlur && active
        }
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.leftMargin: root.pad * 1.3
        anchors.rightMargin: root.pad * 1.3
        anchors.topMargin: root.pad * 0.7
        anchors.bottomMargin: root.pad * 0.5
        spacing: 0

        // the seek bar on top, with the time played and the time left
        RowLayout {
            Layout.fillWidth: true
            spacing: Math.max(4, root.pad * 0.6)

            Text {
                text: root.isMediaActive ? root.formatTime(MprisController.livePosition) : "-:--"
                font.family: ThemeBackend.fontFamily
                font.weight: ThemeBackend.weightBold
                font.pixelSize: root.timeSize
                color: ThemeBackend.subtext0
                Layout.alignment: Qt.AlignVCenter
            }

            WavySeekBar {
                id: progBar
                Layout.fillWidth: true
                Layout.minimumWidth: 20
                Layout.preferredHeight: Math.max(14, root.timeSize * 1.3)
                Layout.maximumHeight: Math.max(14, root.timeSize * 1.3)
                Layout.alignment: Qt.AlignVCenter
                from: 0.0
                to: root.player && root.player.length > 0 ? root.player.length : 100.0
                value: root.isMediaActive ? MprisController.livePosition : 0
                playing: root.player ? root.player.isPlaying : false
                waveColor: ThemeBackend.mauve

                property bool seekPending: false

                Timer {
                    id: seekTimer
                    interval: 1000
                    onTriggered: progBar.seekPending = false
                }

                Connections {
                    target: MprisController
                    function onLivePositionChanged() {
                        if (!progBar.isDragging && !progBar.seekPending) progBar.value = MprisController.livePosition;
                    }
                }

                onMoved: val => {
                    if (root.player && root.player.canSeek) {
                        progBar.seekPending = true;
                        seekTimer.restart();
                        progBar.value = val;
                        root.player.position = val;
                    }
                }
            }

            // time left, counting down
            Text {
                text: root.isMediaActive && root.player ? "-" + root.formatTime(root.player.length - MprisController.livePosition) : "-:--"
                font.family: ThemeBackend.fontFamily
                font.weight: ThemeBackend.weightBold
                font.pixelSize: root.timeSize
                color: ThemeBackend.subtext0
                Layout.alignment: Qt.AlignVCenter
            }
        }

        // repeat, previous / play-pause / next, volume underneath
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.max(4, root.pad * 0.8)

            IconButton {
                Layout.preferredWidth: root.btnSize
                Layout.preferredHeight: root.btnSize
                cornerRadius: Math.round(root.btnSize / 2)
                buttonIcon: root.loopState === MprisLoopState.Track ? String.fromCodePoint(0xF0458) : (root.loopState === MprisLoopState.Playlist ? String.fromCodePoint(0xF0456) : String.fromCodePoint(0xF0457))
                iconFontSize: Math.round(root.iconSize * 0.9)
                accentColor: ThemeBackend.surface1
                bgOpacity: 0.0
                opacity: root.canLoop ? 1.0 : 0.35
                textColor: root.loopState !== MprisLoopState.None ? ThemeBackend.mauve : (isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2)
                onClicked: root.cycleLoop()
            }

            IconButton {
                Layout.preferredWidth: root.btnSize
                Layout.preferredHeight: root.btnSize
                cornerRadius: Math.round(root.btnSize / 2)
                buttonIcon: "󰒮"
                iconFontSize: root.iconSize
                accentColor: ThemeBackend.surface1
                bgOpacity: 0.0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                onClicked: if (root.player && root.player.canGoPrevious) root.player.previous()
            }

            IconButton {
                Layout.preferredWidth: root.btnSize
                Layout.preferredHeight: root.btnSize
                cornerRadius: Math.round(root.btnSize / 2)
                buttonIcon: (root.isMediaActive && MprisController.isPlaying) ? "󰏤" : "󰐊"
                iconFontSize: Math.round(root.iconSize * 1.15)
                accentColor: ThemeBackend.surface1
                bgOpacity: ThemeBackend.liquidGlass ? 1.0 : ThemeBackend.elementOpacity
                textColor: isHoveredOrHighlighted ? ThemeBackend.mauve : ThemeBackend.text
                onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
            }

            IconButton {
                Layout.preferredWidth: root.btnSize
                Layout.preferredHeight: root.btnSize
                cornerRadius: Math.round(root.btnSize / 2)
                buttonIcon: "󰒭"
                iconFontSize: root.iconSize
                accentColor: ThemeBackend.surface1
                bgOpacity: 0.0
                textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                onClicked: if (root.player && root.player.canGoNext) root.player.next()
            }

            Item {
                id: volBox
                Layout.preferredHeight: root.btnSize
                Layout.preferredWidth: root.btnSize + (root.volExpanded ? volSlider.width + root.pad * 0.5 : 0)
                Behavior on Layout.preferredWidth { NumberAnimation { duration: (220) * ThemeBackend.animScale; easing.type: Easing.OutCubic } }
                clip: true

                HoverHandler {
                    id: volHover
                    onHoveredChanged: if (!hovered) volCollapse.restart()
                }

                IconButton {
                    id: volBtn
                    width: root.btnSize
                    height: root.btnSize
                    cornerRadius: Math.round(root.btnSize / 2)
                    buttonIcon: root.volume <= 0.001 ? String.fromCodePoint(0xF0581) : (root.volume < 0.34 ? String.fromCodePoint(0xF057F) : (root.volume < 0.67 ? String.fromCodePoint(0xF0580) : String.fromCodePoint(0xF057E)))
                    iconFontSize: Math.round(root.iconSize * 0.9)
                    accentColor: ThemeBackend.surface1
                    bgOpacity: 0.0
                    textColor: isHoveredOrHighlighted ? ThemeBackend.text : ThemeBackend.overlay2
                    onClicked: root.toggleMute()
                }

                Item {
                    id: volSlider
                    anchors.left: volBtn.right
                    anchors.leftMargin: root.pad * 0.3
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.max(50, root.btnSize * 2.4)
                    height: root.btnSize
                    opacity: root.volExpanded ? 1.0 : 0.0
                    Behavior on opacity { NumberAnimation { duration: (180) * ThemeBackend.animScale } }

                    Rectangle {
                        anchors.verticalCenter: parent.verticalCenter
                        width: parent.width
                        height: Math.max(3, root.btnSize * 0.1)
                        radius: height / 2
                        color: Qt.alpha(ThemeBackend.overlay0, 0.5)
                        Rectangle {
                            width: parent.width * root.volume
                            height: parent.height
                            radius: parent.radius
                            color: ThemeBackend.text
                        }
                    }

                    MouseArea {
                        id: volSliderMa
                        anchors.fill: parent
                        enabled: root.volExpanded
                        cursorShape: Qt.PointingHandCursor
                        onPressed: (mouse) => root.setVolume(mouse.x / width)
                        onPositionChanged: (mouse) => { if (pressed) root.setVolume(mouse.x / width); }
                        onReleased: volCollapse.restart()
                    }
                }

                WheelHandler {
                    acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad
                    onWheel: (event) => root.setVolume(root.volume + (event.angleDelta.y > 0 ? 0.05 : -0.05))
                }
            }
        }
    }
}
