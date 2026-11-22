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
        SmoothRect { smoothing: 0; id: lm; anchors.fill: parent; radius: f.r; visible: false; antialiasing: true; layer.enabled: true; layer.smooth: true }
        SmoothRect { smoothing: 0; anchors.fill: parent; radius: f.r; color: Qt.rgba(0, 0, 0, cov.status === Image.Ready ? 0.4 : 0) }
    }
    LyricLines {
        live: f.live
        anchors.fill: parent
        anchors.margins: Math.max(10, Math.min(24, f.height * 0.06))
        lines: f.opt("lyricsLines", 2)
        offset: Number(f.opt("lyricsOffset", 0)) || 0
        align: f.opt("lyricsAlignment", "left")
        sayMissing: f.opt("showNoLyrics", true)
        hasPlayer: !!f.p
        ink: cov.status === Image.Ready ? "#ffffff" : Theme.text
        size: Math.max(12, Math.min(f.height * 0.2, 17 * Math.pow(Math.max(0.3, Math.sqrt((f.width / 460) * (f.height / 240))), 0.38)))
    }
}
