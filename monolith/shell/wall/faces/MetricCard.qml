import QtQuick
import "../../core"
import "../../ui"

// A usage card: glass, filling with liquid up to the value (a wave on top that moves when it
// changes); the icon top-left, the number top-right, the name bottom-left.
FaceBase {
    id: f
    readonly property bool small: height < 100 || width < 140
    Metric { id: m; type: f.ctx ? f.ctx.type : "cpu" }
    readonly property real r: Theme.corner(80, small ? 10 : 12)
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    WaveFill { id: fill; anchors.fill: parent; radius: f.r; value: m.value; color: m.color; live: f.live; maxAmp: f.small ? 4 : 5 }
    // text under the liquid turns dark, like the card is lit from inside: each line by
    // where it sits, so the name at the bottom and the number at the top switch on their own
    readonly property real surface: height * (1 - fill.level)
    function sunkAt(y) { return fill.level > 0.01 && surface < y; }
    function inkAt(y) { return sunkAt(y) ? Theme.m("on_primary", "#1b1b1f") : Theme.text; }
    readonly property real pad: small ? 10 : 12
    readonly property bool topSunk: sunkAt(pad + ic.height / 2)
    readonly property color topInk: inkAt(pad + ic.height / 2)
    // the name and the detail line under it, each by its own middle
    readonly property color nameInk: inkAt(height - pad - names.height + nameT.height / 2)
    readonly property color detailInk: inkAt(height - pad - detailT.height / 2)
    Item {
        anchors.fill: parent
        anchors.margins: f.pad
        Rectangle {
            id: ic
            width: f.small ? 26 : 30; height: width; radius: Math.min(width / 2, Theme.corner(30, 8))
            color: Qt.alpha(f.topSunk ? "#000000" : Theme.control, f.topSunk ? 0.15 : 0.7)
            Icon { anchors.centerIn: parent; name: m.icon; size: parent.width * 0.58; color: f.topInk }
        }
        Text { anchors.right: parent.right; anchors.verticalCenter: ic.verticalCenter; text: m.text; color: f.topInk; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: f.small ? 18 : 24 }
        Column {
            id: names
            anchors.left: parent.left; anchors.bottom: parent.bottom
            Text { id: nameT; text: m.title; color: Qt.alpha(f.nameInk, 0.9); font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.small ? 11 : 13 }
            Text { id: detailT; visible: !f.small && m.detail !== ""; text: m.detail; color: Qt.alpha(f.detailInk, 0.75); font.family: Theme.fontFamily; font.pixelSize: 11 }
        }
    }
}
