import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Lyrics, simple: just the lines, straight on the wallpaper with a soft shadow; the text grows
// gently with the widget.
FaceBase {
    id: f
    readonly property real k: Math.pow(Math.max(0.3, Math.sqrt((width / 320) * (height / 100))), 0.38)
    // how the lines come in: scrolling with the song (LyricLines), or one at a time (LyricPop:
    // pop, slide, word by word). LyricLines also says when there are no lyrics
    readonly property string style: { const v = f.opt("lyricsStyle", "scroll"); return ["pop", "slide", "words"].indexOf(v) !== -1 ? v : "scroll"; }
    readonly property bool scrolling: style === "scroll" || Lyrics.lines.length === 0
    LyricLines {
        live: f.live
        anchors.fill: parent
        visible: f.scrolling
        lines: f.opt("lyricsLines", 1)
        align: f.opt("lyricsAlignment", "left")
        sayMissing: f.opt("showNoLyrics", true)
        offset: Number(f.opt("lyricsOffset", 0)) || 0
        hasPlayer: !!f.player
        side: Math.max(12, f.width * 0.05)
        ink: "#ffffff"
        size: Math.max(11, Math.min(f.height * 0.24, 15 * f.k))
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 1.5; shadowBlur: 0.35; shadowOpacity: 0.55 }
    }
    LyricPop {
        anchors.fill: parent
        visible: !f.scrolling && !!f.player
        mode: f.style
        offset: Number(f.opt("lyricsOffset", 0)) || 0
        align: f.opt("lyricsAlignment", "left")
        side: Math.max(12, f.width * 0.05)
        // (the line being sung, in the accent colour as in the scrolling column)
        ink: Theme.accent
        size: Math.max(11, Math.min(f.height * 0.3, 17 * f.k))
        layer.enabled: true
        layer.effect: MultiEffect { shadowEnabled: true; shadowColor: "#000000"; shadowVerticalOffset: 1.5; shadowBlur: 0.35; shadowOpacity: 0.55 }
    }
}
