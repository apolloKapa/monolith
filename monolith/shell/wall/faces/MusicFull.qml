import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Music: glass with the visualiser rising behind it; the cover on the left, the title (heavy)
// and artist, the controls, and the progress.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property real r: Theme.corner(80, 14)
    readonly property real m: Math.max(8, Math.min(16, height * 0.1))
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    Item {
        anchors.fill: parent
        clip: true
        visible: f.opt("showBars", true)
        CavaBars { anchors.left: parent.left; anchors.right: parent.right; anchors.bottom: parent.bottom; height: parent.height * 0.55; live: f.live && !!f.p && f.p.isPlaying; continuous: f.opt("continuous", false); opacity: 0.35 }
    }
    Rectangle {
        id: art
        x: f.m; anchors.verticalCenter: parent.verticalCenter
        width: Math.min(200, f.height - 2 * f.m); height: width
        radius: Theme.corner(width, 8)
        color: Theme.control
        clip: true
        Icon { anchors.centerIn: parent; name: "music_note"; size: parent.width * 0.4; color: Theme.subtext; visible: cov.status !== Image.Ready }
        Image { id: cov; anchors.fill: parent; source: f.p ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; asynchronous: true; visible: false }
        MultiEffect { anchors.fill: parent; source: cov; visible: cov.status === Image.Ready; maskEnabled: true; maskSource: artMask }
        Rectangle { id: artMask; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
    }
    Item {
        anchors.left: art.right; anchors.leftMargin: f.m
        anchors.right: parent.right; anchors.rightMargin: f.m
        anchors.top: art.top; anchors.bottom: art.bottom
        Text { id: ttl; width: parent.width; elide: Text.ElideRight; text: f.p ? (f.p.trackTitle || "Unknown track") : "Nothing playing"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: Math.max(13, Math.min(24, f.height * 0.16)) }
        Text { anchors.top: ttl.bottom; width: parent.width; elide: Text.ElideRight; visible: !!f.p; text: f.p ? (f.p.trackArtist || "") : ""; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: Math.max(10, Math.min(15, f.height * 0.11)) }
        Rectangle {
            anchors.bottom: ctl.top; anchors.bottomMargin: 6
            width: parent.width; height: 4; radius: 2; color: Qt.alpha(Theme.text, 0.15)
            visible: !!f.p && f.p.length > 0
            Rectangle { height: parent.height; radius: 2; color: Theme.accent; width: f.p && f.p.length > 0 ? parent.width * Math.min(1, f.p.position / f.p.length) : 0 }
        }
        Row {
            id: ctl
            anchors.bottom: parent.bottom
            spacing: 4
            readonly property real b: Math.max(26, Math.min(40, f.height * 0.26))
            Repeater {
                model: [["skip_previous", 0], [f.p && f.p.isPlaying ? "pause" : "play_arrow", 1], ["skip_next", 2]]
                Pressable {
                    required property var modelData
                    width: modelData[1] === 1 ? ctl.b * 1.3 : ctl.b; height: ctl.b
                    color: modelData[1] === 1 ? Theme.accent : (hovered ? Qt.alpha(Theme.text, 0.1) : "transparent")
                    ink: modelData[1] === 1 ? Theme.onAccent : Theme.text
                    enabledInput: !!f.p
                    onClicked: modelData[1] === 0 ? f.p.previous() : (modelData[1] === 1 ? f.p.togglePlaying() : f.p.next())
                    Icon { anchors.centerIn: parent; name: parent.modelData[0]; filled: true; size: ctl.b * 0.58; color: parent.modelData[1] === 1 ? Theme.onAccent : Theme.text }
                }
            }
        }
    }
}
