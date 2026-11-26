import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Music: on glass with a faint visualiser rising from the bottom edge; the cover on the left, and
// beside it the title (scrolling when it's long), the artist, the time either side of a wavy seek
// bar you can drag, and previous / play-pause / next. The smaller the widget, the less of it
// there is: the time goes first, then the artist and the cover.
FaceBase {
    id: face
    readonly property var mp: face.player
    readonly property bool hasTrack: !!mp && mp.trackTitle !== ""
    readonly property real corner: Theme.corner(80, 14)
    // sizes from the height, each between a floor and a ceiling
    function band(part, lo, hi) { return Math.max(lo, Math.min(hi, height * part)); }
    readonly property real pad: band(0.12, 6, 24)
    readonly property real gap: band(0.08, 4, 20)
    readonly property real key: band(0.24, 18, 56)
    readonly property real titlePx: band(0.14, 10, 24)
    readonly property real smallPx: band(0.1, 8, 16)
    // what there's room for
    readonly property bool roomForArtist: height >= 62
    readonly property bool roomForCover: roomForArtist && width >= 175
    readonly property bool roomForTime: height >= 80
    readonly property bool roomForBars: height >= 52 && face.opt("showBars", true)
    PlayPosition { id: clock; player: face.hasTrack ? face.mp : null; active: face.live && face.visible && face.roomForTime }
    // seconds as mm:ss (a leading zero under ten minutes)
    function stamp(sec) {
        const t = Math.max(0, Math.floor(sec || 0)), m = Math.floor(t / 60), s = t % 60;
        return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s;
    }
    component Small: Text { renderType: Text.CurveRendering; color: Theme.subtext; font.family: Theme.fontFamily }
    // the card's shape, for clipping what's drawn inside it
    component CardShape: SmoothRect { smoothing: 0; anchors.fill: parent; visible: false; antialiasing: true; layer.enabled: true; layer.smooth: true }

    Glass { anchors.fill: parent; ctx: face.ctx; radius: face.corner }
    CardShape { id: cardShape; radius: face.corner }
    Item {
        visible: face.roomForBars
        anchors.fill: parent
        layer.enabled: true
        layer.effect: MultiEffect { maskEnabled: true; maskSource: cardShape }
        CavaBars {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            height: Math.max(20, parent.height * 0.55) * 0.55
            opacity: 0.2
            live: face.live && !!face.mp && face.mp.isPlaying
            continuous: face.opt("continuous", false)
        }
    }

    Item {
        anchors.fill: parent
        anchors.margins: face.pad
        SmoothRect {
            id: cover
            smoothing: 0   // (square corners in the plain styles; Cyberpunk cuts one)
            visible: face.roomForCover
            width: face.roomForCover ? Math.min(200, parent.height) : 0
            height: width
            anchors.left: parent.left
            anchors.verticalCenter: parent.verticalCenter
            radius: Theme.corner(width, 8)
            color: Theme.control
            Icon { visible: art.status !== Image.Ready; anchors.centerIn: parent; name: "music_note"; size: parent.width * 0.38; color: Theme.subtext }
            Image { id: art; visible: false; anchors.fill: parent; asynchronous: true; fillMode: Image.PreserveAspectCrop; source: face.hasTrack ? (face.mp.trackArtUrl || "") : "" }
            CardShape { id: coverShape; radius: cover.radius }
            MultiEffect { visible: art.status === Image.Ready; anchors.fill: parent; source: art; maskEnabled: true; maskSource: coverShape }
        }
        Item {
            anchors.left: face.roomForCover ? cover.right : parent.left
            anchors.leftMargin: face.roomForCover ? face.gap : 0
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.bottom: parent.bottom
            Marquee {
                id: title
                width: parent.width
                active: face.live && face.hasTrack
                text: face.hasTrack ? (face.mp.trackTitle || "Unknown track") : "Nothing playing"
                color: Theme.text
                font.family: Theme.fontFamily
                font.weight: Font.Black
                font.pixelSize: face.titlePx
            }
            Small {
                id: byline
                visible: face.hasTrack && face.roomForArtist
                width: parent.width
                anchors.top: title.bottom
                anchors.topMargin: Math.max(1, face.gap / 5)
                elide: Text.ElideRight
                text: face.hasTrack ? (face.mp.trackArtist || "Unknown artist") : ""
                font.weight: Font.Medium
                font.pixelSize: face.smallPx
            }
            RowLayout {
                visible: face.roomForTime && face.hasTrack
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.top: byline.visible ? byline.bottom : title.bottom
                anchors.bottom: keys.top
                spacing: Math.max(4, face.gap * 0.4)
                Small { text: face.hasTrack ? face.stamp(clock.shown) : "--:--"; font.weight: Font.Bold; font.pixelSize: Math.max(7, face.smallPx * 0.85) }
                WavySeek {
                    Layout.fillWidth: true
                    Layout.preferredHeight: Math.max(14, Math.round(face.smallPx * 1.2))
                    live: face.live
                    value: face.hasTrack ? clock.shown : 0
                    to: face.hasTrack && face.mp.length > 0 ? face.mp.length : 1
                    playing: face.hasTrack && face.mp.isPlaying
                    onMoved: v => { if (face.mp && face.mp.canSeek) { face.mp.position = v; clock.sync(); } }
                }
                Small { text: face.hasTrack ? face.stamp(face.mp.length) : "--:--"; font.weight: Font.Bold; font.pixelSize: Math.max(7, face.smallPx * 0.85) }
            }
            // a square key; the middle one (play) stands out when hovered
            component Key: Pressable {
                id: k
                property string glyph
                property bool middle: false
                width: face.key
                height: face.key
                radius: Math.max(4, face.key / 5)
                color: hovered ? Theme.containerHigh : Qt.alpha(Theme.control, 0.85)
                enabledInput: face.live && !!face.mp
                Icon {
                    anchors.centerIn: parent
                    name: k.glyph
                    filled: true
                    size: Math.max(12, face.key / 2)
                    color: k.middle ? (k.hovered ? Theme.accent : Theme.text) : (k.hovered ? Theme.text : Theme.subtext)
                }
            }
            Row {
                id: keys
                anchors.bottom: parent.bottom
                spacing: Math.max(2, face.gap / 2)
                Key { glyph: "skip_previous"; onClicked: face.mp.previous() }
                Key { glyph: face.hasTrack && face.mp.isPlaying ? "pause" : "play_arrow"; middle: true; onClicked: face.mp.togglePlaying() }
                Key { glyph: "skip_next"; onClicked: face.mp.next() }
            }
        }
    }
}
