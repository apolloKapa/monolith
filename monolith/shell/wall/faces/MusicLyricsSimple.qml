import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Lyrics, simple: just the lines, straight on the wallpaper with a soft shadow; the text grows
// gently with the widget.
FaceBase {
    id: f
    readonly property real k: Math.pow(Math.max(0.3, Math.sqrt((width / 320) * (height / 100))), 0.38)
    LyricLines {
        live: f.live
        anchors.fill: parent
        lines: f.opt("lyricsLines", 1)
        align: f.opt("lyricsAlignment", "left")
        sayMissing: f.opt("showNoLyrics", true)
        hasPlayer: !!f.player
        side: Math.max(12, f.width * 0.05)
        ink: "#ffffff"
        size: Math.max(11, Math.min(f.height * 0.24, 15 * f.k))
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 1.5; shadowBlur: 0.35; shadowOpacity: 0.55 }
    }
}
