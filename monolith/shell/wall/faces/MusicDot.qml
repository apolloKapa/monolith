import QtQuick
import "../../core"
import "../../ui"

// Music, Dot: what's playing in plain words, a row of dots for how far in it is (the playhead
// red), and round previous / play / next buttons.
FaceBase {
    id: f
    DotCard { id: card; ctx: f.ctx }
    readonly property real pad: Math.min(width, height) * 0.14
    readonly property real len: player && player.length > 0 ? player.length : 0
    readonly property real frac: len > 0 ? Math.min(1, player.position / len) : 0
    readonly property bool playing: !!player && player.isPlaying

    Column {
        x: f.pad; y: f.pad
        width: f.width - 2 * f.pad - ctl.width - f.pad * 0.5
        spacing: 2
        Text { width: parent.width; elide: Text.ElideRight; text: f.player ? (f.player.trackTitle || "Unknown") : "Nothing playing"; color: card.ink; font.family: Theme.fontFamily; font.pixelSize: Math.max(12, f.height * 0.13); font.weight: Font.Bold }
        Text { width: parent.width; elide: Text.ElideRight; text: f.player ? (f.player.trackArtist || "").toUpperCase() : ""; color: card.dim; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, f.height * 0.075); font.letterSpacing: 1 }
    }
    // how far in: dots, lit up to the playhead
    Row {
        id: dots
        readonly property int n: Math.max(8, Math.floor((f.width - 2 * f.pad) / Math.max(6, f.height * 0.07)))
        readonly property real d: (f.width - 2 * f.pad) / n
        x: f.pad
        anchors.bottom: parent.bottom; anchors.bottomMargin: f.pad
        Repeater {
            model: dots.n
            Item {
                required property int index
                width: dots.d; height: dots.d
                readonly property int head: Math.round(f.frac * (dots.n - 1))
                Rectangle {
                    anchors.centerIn: parent
                    width: parent.width * (index === parent.head ? 0.8 : 0.5); height: width; radius: width / 2
                    color: index === parent.head ? card.accent : (index < parent.head ? card.ink : card.off)
                }
            }
        }
    }
    Row {
        id: ctl
        anchors.right: parent.right; anchors.rightMargin: f.pad
        y: f.pad * 0.8
        spacing: f.height * 0.04
        Repeater {
            model: [["skip_previous", 0], [f.playing ? "pause" : "play_arrow", 1], ["skip_next", 2]]
            Rectangle {
                required property var modelData
                readonly property bool main: modelData[1] === 1
                width: f.height * (main ? 0.3 : 0.24); height: width; radius: width / 2
                anchors.verticalCenter: parent.verticalCenter
                color: main ? card.ink : card.off
                Icon { anchors.centerIn: parent; name: parent.modelData[0]; filled: true; size: parent.width * 0.55; color: parent.main ? (card.light ? "#ececea" : "#0b0b0b") : card.ink }
                MouseArea {
                    anchors.fill: parent
                    enabled: f.live && !!f.player
                    cursorShape: Qt.PointingHandCursor
                    onClicked: parent.modelData[1] === 0 ? f.player.previous() : (parent.modelData[1] === 1 ? f.player.togglePlaying() : f.player.next())
                }
            }
        }
    }
}
