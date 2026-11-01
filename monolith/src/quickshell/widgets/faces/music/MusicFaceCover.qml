import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Services.Mpris
import "../../../reusables"
import "../../../"

// Just the album cover. coverRoundness is the corner radius as a share of the side:
// 0 is a sharp square, 0.5 is a circle. Clicking it plays/pauses.
Item {
    id: root
    anchors.fill: parent

    property real minWidth: 80
    property real minHeight: 80
    property real maxWidth: 1000
    property real maxHeight: 1000
    property real minAspect: 1.0
    property real maxAspect: 1.0

    property real coverRoundness: 0.12

    property var player: MprisController.activePlayer
    property bool isMediaActive: player !== null && player.playbackState !== MprisPlaybackState.Stopped && player.trackTitle !== ""
    readonly property bool hasArt: isMediaActive && MprisController.artUrl !== "" && artImg.status === Image.Ready
    readonly property real cornerRadius: Math.min(width, height) * Math.max(0, Math.min(0.5, coverRoundness))

    Rectangle {
        id: placeholder
        anchors.fill: parent
        radius: root.cornerRadius
        color: Qt.alpha(ThemeBackend.surface0, ThemeBackend.elementOpacity)
        opacity: root.hasArt ? 0.0 : 1.0
        Behavior on opacity { NumberAnimation { duration: (400) * ThemeBackend.animScale } }

        Text {
            anchors.centerIn: parent
            text: "󰝚"
            font.pixelSize: parent.width * 0.3
            color: ThemeBackend.overlay1
        }
    }

    Image {
        id: artImg
        anchors.fill: parent
        source: (root.isMediaActive && MprisController.artUrl) ? (MprisController.artUrl.startsWith("file://") || MprisController.artUrl.startsWith("http") ? MprisController.artUrl : "file://" + MprisController.artUrl) : ""
        fillMode: Image.PreserveAspectCrop
        sourceSize: Qt.size(Math.max(64, width * 2), Math.max(64, height * 2))
        asynchronous: true
        visible: false
    }

    Rectangle {
        id: artMask
        anchors.fill: parent
        radius: root.cornerRadius
        visible: false
        layer.enabled: true
    }

    MultiEffect {
        anchors.fill: parent
        source: artImg
        maskEnabled: true
        maskSource: artMask
        opacity: root.hasArt ? 1.0 : 0.0
        Behavior on opacity { NumberAnimation { duration: (600) * ThemeBackend.animScale } }
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: Qt.PointingHandCursor
        onClicked: if (root.player && root.player.canTogglePlaying) root.player.togglePlaying()
    }
}
