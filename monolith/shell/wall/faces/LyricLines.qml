import QtQuick
import "../../core"
import "../../ui"

// The synced lyrics around the current line: `lines` of them, the current one big and bright,
// the rest smaller and fading, sliding up as the song goes on.
Item {
    id: ll
    property int lines: 3
    property string align: "center"
    property bool sayMissing: true
    property bool hasPlayer: false
    property color ink: Theme.text
    property real size: 20
    readonly property int cur: Lyrics.currentIndex
    readonly property bool have: Lyrics.lines.length > 0
    clip: true
    Column {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        spacing: ll.size * 0.35
        visible: ll.have
        Repeater {
            model: ll.lines
            Text {
                required property int index
                readonly property int off: index - Math.floor((ll.lines - 1) / 2)
                readonly property int at: ll.cur + off
                width: parent.width
                horizontalAlignment: ll.align === "left" ? Text.AlignLeft : (ll.align === "right" ? Text.AlignRight : Text.AlignHCenter)
                elide: Text.ElideRight
                text: at >= 0 && at < Lyrics.lines.length ? (Lyrics.lines[at].text || "♪") : ""
                color: off === 0 ? ll.ink : Qt.alpha(ll.ink, Math.max(0.2, 0.6 - Math.abs(off) * 0.15))
                font.family: Theme.fontFamily
                font.pixelSize: off === 0 ? ll.size : ll.size * 0.72
                font.weight: off === 0 ? Font.Black : Font.DemiBold
                Behavior on font.pixelSize { NumberAnimation { duration: 220 } }
            }
        }
    }
    property bool live: true
    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 8
        visible: !ll.have && ll.sayMissing
        Text {
            width: parent.width
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
        text: !ll.hasPlayer ? "Nothing playing" : (Lyrics.state === "loading" ? "Looking for lyrics…" : "No synced lyrics for this song")
        color: Qt.alpha(ll.ink, 0.6)
        font.family: Theme.fontFamily; font.weight: Font.DemiBold; font.pixelSize: Math.max(11, ll.size * 0.6)
    }
    // none found: pick a lyrics file for this song (remembered)
    Rectangle {
        visible: ll.hasPlayer && Lyrics.state !== "loading" && ll.height > 70
        anchors.horizontalCenter: parent.horizontalCenter
        height: 28; width: pr.implicitWidth + 20; radius: Theme.corner(28, 8)
        color: Qt.alpha(pm.containsMouse ? Theme.containerHigh : Theme.control, 0.85)
        Row { id: pr; anchors.centerIn: parent; spacing: 6
            Icon { name: "folder_open"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
            Text { text: "Pick a lyrics file"; color: ll.ink; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } }
        MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; enabled: ll.live; cursorShape: Qt.PointingHandCursor; onClicked: Lyrics.pickFile() }
    }
    }
}
