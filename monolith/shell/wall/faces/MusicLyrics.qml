import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Lyrics: a card with the cover blurred and darkened behind the synced lines.
FaceBase {
    id: f
    readonly property var p: f.player
    readonly property real r: Theme.corner(80, 16)
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    Item {
        anchors.fill: parent
        Image { id: cov; anchors.fill: parent; source: f.p ? (f.p.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(200, 200); visible: false; asynchronous: true }
        MultiEffect { anchors.fill: parent; source: cov; visible: cov.status === Image.Ready; blurEnabled: true; blur: 1; blurMax: 48; opacity: 0.6; maskEnabled: true; maskSource: lm }
        Rectangle { id: lm; anchors.fill: parent; radius: f.r; visible: false; layer.enabled: true }
        Rectangle { anchors.fill: parent; radius: f.r; color: Qt.rgba(0, 0, 0, cov.status === Image.Ready ? 0.4 : 0) }
    }
    LyricLines {
        anchors.fill: parent
        anchors.margins: Math.max(10, Math.min(24, f.height * 0.08))
        lines: f.opt("lyricsLines", 3)
        align: f.opt("lyricsAlignment", "center")
        sayMissing: f.opt("showNoLyrics", true)
        hasPlayer: !!f.p
        size: Math.max(13, Math.min(30, f.height / (lines * 1.6 + 1)))
    }
}
