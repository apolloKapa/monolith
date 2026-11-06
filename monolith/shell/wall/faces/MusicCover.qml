import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Music, cover: the album art as a rounded square, the title and artist over a dark fade at the
// bottom; click to play or pause.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property real r: Theme.corner(80, 14)
    Rectangle { anchors.fill: parent; radius: f.r; color: Theme.control }
    Icon { anchors.centerIn: parent; name: "music_note"; size: Math.min(f.width, f.height) * 0.3; color: Theme.subtext; visible: cov.status !== Image.Ready }
    Image { id: cov; anchors.fill: parent; source: f.p ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
    MultiEffect { anchors.fill: parent; source: cov; visible: cov.status === Image.Ready; maskEnabled: true; maskSource: cm }
    Rectangle { id: cm; anchors.fill: parent; radius: f.r; visible: false; layer.enabled: true }
    Rectangle {
        anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom
        height: parent.height * 0.36
        radius: f.r
        gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.75) } }
        Column {
            x: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 10; width: parent.width - 24
            Text { width: parent.width; elide: Text.ElideRight; text: f.p ? f.p.trackTitle : "Nothing playing"; color: "white"; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: Math.max(11, f.height * 0.07) }
            Text { width: parent.width; elide: Text.ElideRight; text: f.p ? f.p.trackArtist : ""; color: Qt.rgba(1, 1, 1, 0.75); font.family: Theme.fontFamily; font.pixelSize: Math.max(9, f.height * 0.055) }
        }
    }
    MouseArea { anchors.fill: parent; enabled: f.live && !!f.p; cursorShape: Qt.PointingHandCursor; onClicked: f.p.togglePlaying() }
}
