import QtQuick
import "../../core"
import "../../ui"

// Now playing, Cyberpunk: AUDIO FEED. The title with its split signal, the artist in yellow, how
// far along as segments, and three hard-edged buttons (back, play/pause, next).
FaceBase {
    id: f
    readonly property var p: f.player
    PlayPosition { id: pp; player: f.p; active: f.live && f.visible }
    CyberCard {
        id: c; ctx: f.ctx; label: f.p && f.p.isPlaying ? "Audio feed // live" : "Audio feed"
        CyberText { id: title; card: c; width: parent.width; height: parent.height * 0.3; text: f.p ? (f.p.trackTitle || "Unknown") : "No signal" }
        CyberText { y: title.height + c.u * 0.02; card: c; width: parent.width; height: parent.height * 0.17; ghosts: false; color: c.neon; text: f.p ? String(f.p.trackArtist || "").toUpperCase() : "" }
        CyberBar { y: parent.height * 0.58; card: c; width: parent.width; height: Math.max(3, c.u * 0.045); count: 24; value: pp.len > 0 ? pp.shown / pp.len : 0 }
        Row {
            anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter
            spacing: c.u * 0.06
            Repeater {
                model: [["skip_previous", () => f.p && f.p.previous()], [f.p && f.p.isPlaying ? "pause" : "play_arrow", () => f.p && f.p.togglePlaying()], ["skip_next", () => f.p && f.p.next()]]
                Rectangle {
                    required property var modelData
                    required property int index
                    width: c.u * (index === 1 ? 0.34 : 0.26); height: c.u * 0.22
                    color: index === 1 ? c.edge : "transparent"
                    border.width: index === 1 ? 0 : c.line; border.color: c.edge
                    Icon { anchors.centerIn: parent; name: parent.modelData[0]; size: parent.height * 0.8; filled: true; color: index === 1 ? "#0a0a12" : c.edge }
                    MouseArea { anchors.fill: parent; enabled: !!f.p; cursorShape: Qt.PointingHandCursor; onClicked: parent.modelData[1]() }
                }
            }
        }
    }
}
