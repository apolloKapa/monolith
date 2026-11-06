import QtQuick
import QtQuick.Effects
import Quickshell.Services.Mpris
import "../../core"
import "../../ui"

// Music, controls: glass; the cover, title and artist, the five controls and the progress
// with times.
FaceBase {
    id: f
    PlayPosition { id: pp; player: f.p; active: f.live && f.visible }
    readonly property var p: f.player
    function mmss(t) { t = Math.max(0, Math.floor(t || 0)); return Math.floor(t / 60) + ":" + String(t % 60).padStart(2, "0"); }
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 380; dh: 160
        Rectangle {
            id: art
            x: 14; y: 14; width: 92; height: 92; radius: Theme.corner(92, 8); color: Theme.control; clip: true
            Icon { anchors.centerIn: parent; name: "music_note"; size: 36; color: Theme.subtext; visible: cov.status !== Image.Ready }
            Image { id: cov; anchors.fill: parent; source: f.p ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; visible: false; asynchronous: true }
            MultiEffect { anchors.fill: parent; source: cov; visible: cov.status === Image.Ready; maskEnabled: true; maskSource: am }
            Rectangle { id: am; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
        }
        Column {
            anchors.left: art.right; anchors.leftMargin: 14; anchors.right: parent.right; anchors.rightMargin: 14
            y: 16
            Text { width: parent.width; elide: Text.ElideRight; text: f.p ? f.p.trackTitle : "Nothing playing"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 18 }
            Text { width: parent.width; elide: Text.ElideRight; text: f.p ? f.p.trackArtist : ""; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 13 }
            Item { width: 1; height: 10 }
            Row {
                spacing: 4
                Repeater {
                    model: [["shuffle", 3], ["skip_previous", 0], [f.p && f.p.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2], ["repeat", 4]]
                    Pressable {
                        required property var modelData
                        width: modelData[1] === 1 ? 46 : 36; height: modelData[1] === 1 ? 40 : 36
                        anchors.verticalCenter: parent.verticalCenter
                        color: modelData[1] === 1 ? Theme.accent : (hovered ? Qt.alpha(Theme.text, 0.1) : "transparent")
                        ink: modelData[1] === 1 ? Theme.onAccent : Theme.text
                        enabledInput: !!f.p
                        onClicked: {
                            const k = modelData[1];
                            if (k === 0) f.p.previous(); else if (k === 1) f.p.togglePlaying(); else if (k === 2) f.p.next();
                            else if (k === 3 && f.p.shuffleSupported) f.p.shuffle = !f.p.shuffle;
                            else if (k === 4 && f.p.loopSupported) f.p.loopState = f.p.loopState === MprisLoopState.None ? MprisLoopState.Playlist : MprisLoopState.None;
                        }
                        Icon { anchors.centerIn: parent; name: parent.modelData[0]; filled: true; size: parent.modelData[1] === 1 ? 24 : 20; color: parent.modelData[1] === 1 ? Theme.onAccent : Theme.text }
                    }
                }
            }
        }
        Item {
            x: 14; y: 120; width: parent.width - 28; height: 30
            Rectangle { y: 4; width: parent.width; height: 5; radius: 3; color: Qt.alpha(Theme.text, 0.15)
                Rectangle { height: parent.height; radius: 3; color: Theme.accent; width: f.p && f.p.length > 0 ? parent.width * Math.min(1, pp.shown / f.p.length) : 0 } }
            Text { y: 13; text: f.p ? f.mmss(pp.shown) : "0:00"; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
            Text { y: 13; anchors.right: parent.right; text: f.p ? f.mmss(f.p.length) : "0:00"; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
        }
    }
}
