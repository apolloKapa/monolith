import QtQuick
import "../../core"
import "../../ui"

// Synced lyrics as one column that scrolls with the song: the line being sung sits a little
// above the middle in the accent colour, the ones around it smaller and dimmer; `lines` of them
// show on each side (the rest fade out). Scroll to look through the song (it comes back after a
// few seconds, or on right-click); click a line to jump there.
Item {
    id: ll
    property int lines: 1                        // shown on each side of the current line
    property string align: "left"
    property bool sayMissing: true
    property bool hasPlayer: false
    property bool live: true
    property color ink: Theme.text
    property color activeInk: Theme.accent
    property real inactiveOpacity: 0.7
    property real size: 16
    property real side: 4
    readonly property real lineH: Math.max(18, size * 1.4)
    readonly property real gap: Math.max(2, size * 0.25)
    readonly property int cur: Lyrics.currentIndex
    readonly property bool have: Lyrics.lines.length > 0
    readonly property int hAlign: align === "center" ? Text.AlignHCenter : (align === "right" ? Text.AlignRight : Text.AlignLeft)
    clip: true

    // where the column sits: the current line's middle at 44 % of the height, unless you scrolled
    property bool browsing: false
    property real browseY: 0
    readonly property real autoY: {
        const c = height * 0.44;
        const it = rep.count > Math.max(0, cur) ? rep.itemAt(Math.max(0, cur)) : null;
        return c - (it ? it.y + it.height / 2 : lineH / 2);
    }
    Timer { id: back; interval: 4000; onTriggered: ll.browsing = false }
    function browse(delta) {
        if (!have) return;
        if (!browsing) { browseY = autoY; browsing = true; }
        const c = height * 0.44;
        browseY = Math.max(c - col.height + lineH / 2 - 40, Math.min(c - lineH / 2 + 40, browseY + delta / 120 * (lineH + gap) * 1.5));
        back.restart();
    }
    WheelHandler { enabled: ll.live; target: null; acceptedDevices: PointerDevice.Mouse | PointerDevice.TouchPad; onWheel: e => ll.browse(e.angleDelta.y !== 0 ? e.angleDelta.y : e.angleDelta.x) }
    TapHandler { enabled: ll.live; acceptedButtons: Qt.RightButton; onTapped: { back.stop(); ll.browsing = false; } }

    Column {
        id: col
        visible: ll.have
        width: parent.width
        spacing: ll.gap
        y: ll.browsing ? ll.browseY : ll.autoY
        Behavior on y { NumberAnimation { duration: Theme.ms(650); easing.type: Easing.OutCubic } }
        Repeater {
            id: rep
            model: Lyrics.lines
            Item {
                id: row
                required property var modelData
                required property int index
                readonly property int dist: index - ll.cur
                readonly property bool near: ll.browsing || Math.abs(dist) <= ll.lines
                width: col.width
                height: Math.max(ll.lineH, t.implicitHeight)
                Text {
                    id: t
                    width: Math.min(parent.width - 2 * ll.side, implicitWidth)
                    x: ll.hAlign === Text.AlignHCenter ? Math.round((parent.width - width) / 2) : (ll.hAlign === Text.AlignRight ? parent.width - ll.side - width : ll.side)
                    anchors.verticalCenter: parent.verticalCenter
                    horizontalAlignment: ll.hAlign
                    wrapMode: Text.WordWrap
                    Balance {}   // balanced lines (ui/Balance)
                    text: row.modelData.text !== "" ? row.modelData.text : "♪"
                    font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: ll.size
                    color: row.dist === 0 ? ll.activeInk : ll.ink
                    opacity: !row.near ? 0 : (row.dist === 0 ? 1 : ll.inactiveOpacity)
                    scale: row.dist === 0 ? 1 : (Math.abs(row.dist) === 1 ? 0.88 : 0.8)
                    transformOrigin: ll.hAlign === Text.AlignHCenter ? Item.Center : (ll.hAlign === Text.AlignRight ? Item.Right : Item.Left)
                    visible: opacity > 0
                    Behavior on color { ColorAnimation { duration: Theme.ms(650); easing.type: Easing.OutCubic } }
                    Behavior on opacity { NumberAnimation { duration: Theme.ms(650); easing.type: Easing.OutCubic } }
                    Behavior on scale { NumberAnimation { duration: Theme.ms(650); easing.type: Easing.OutCubic } }
                }
                MouseArea {
                    anchors.fill: parent
                    enabled: ll.live && row.near
                    cursorShape: Qt.PointingHandCursor
                    onClicked: { const p = Lyrics.player; if (p && p.canSeek) p.position = row.modelData.t; back.stop(); ll.browsing = false; }
                }
            }
        }
    }

    Column {
        anchors.centerIn: parent
        width: parent.width
        spacing: 8
        // nothing playing: nothing at all (cleaner on the desktop)
        visible: ll.hasPlayer && !ll.have && (ll.sayMissing || Lyrics.state === "loading")
        Text {
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            Balance {}   // balanced lines (ui/Balance)
            text: Lyrics.state === "loading" ? "Looking for lyrics…" : "No lyrics for this song"
            color: Theme.subtext
            font.family: Theme.fontFamily; font.weight: Font.DemiBold; font.pixelSize: Math.max(11, Math.min(14, ll.size * 0.8))
        }
        // none found: pick a lyrics file for this song (remembered)
        Rectangle {
            visible: ll.hasPlayer && Lyrics.state !== "loading" && ll.height > 70
            anchors.horizontalCenter: parent.horizontalCenter
            height: 28; width: pr.implicitWidth + 20; radius: Theme.corner(28, 8)
            color: Qt.alpha(pm.containsMouse ? Theme.containerHigh : Theme.control, 0.85)
            Behavior on color { ColorAnimation { duration: Theme.fastMs; easing.type: Easing.OutCubic } }
            Row { id: pr; anchors.centerIn: parent; spacing: 6
                Icon { name: "folder_open"; size: 15; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Pick a lyrics file"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter } }
            MouseArea { id: pm; anchors.fill: parent; hoverEnabled: true; enabled: ll.live; cursorShape: Qt.PointingHandCursor; onClicked: Lyrics.pickFile() }
        }
    }
}
