import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../reusables/inputs"
import "../../../"

// A slim player: the seek bar with the time left on top, previous / play-pause / next under it.
Item {
    id: root
    anchors.fill: parent

    property real minWidth: 200
    property real minHeight: 70
    property real maxWidth: 1400
    property real maxHeight: 260
    property real minAspect: 1.6
    property real maxAspect: 8.0

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""

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
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        radius: ThemeBackend.rad(Math.min(height / 2, ThemeBackend.borderRadius * 1.5))

        WallpaperBlur {
            z: -1
            anchors.fill: parent
            radius: bg.radius
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

        // previous / play-pause / next underneath
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: Math.max(4, root.pad * 0.8)

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
        }
    }
}
