import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Lyrics, simple: just the lines, straight on the wallpaper.
FaceBase {
    id: f
    LyricLines {
        anchors.fill: parent
        lines: f.opt("lyricsLines", 3)
        align: f.opt("lyricsAlignment", "center")
        sayMissing: f.opt("showNoLyrics", true)
        hasPlayer: !!f.player
        size: Math.max(13, Math.min(40, f.height / (lines * 1.5)))
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 2; shadowBlur: 0.4; shadowOpacity: 0.6 }
    }
}
