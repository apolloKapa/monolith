import QtQuick
import "../../core"

// Clock, Dot: the hours and minutes in big round dots on a flat card, the day and date small
// under them, and a red dot that pulses with the seconds.
FaceBase {
    id: f
    DotCard { id: card; ctx: f.ctx }
    readonly property real pad: Math.min(width, height) * 0.12
    readonly property bool tall: height > width * 0.75
    readonly property string hm: Qt.formatTime(f.now, f.opt("hour12", false) ? "h:mm" : "HH:mm")
    readonly property string day: Qt.formatDate(f.now, "ddd d MMM").toUpperCase()

    DotText {
        id: big
        text: f.hm
        color: card.ink
        offColor: f.opt("offDots", true) ? card.off : "transparent"
        cell: fitCell(f.width - 2 * f.pad, (f.height - 2 * f.pad) * (f.opt("showDate", true) ? 0.66 : 1))
        x: (f.width - width) / 2
        y: f.opt("showDate", true) ? f.pad : (f.height - height) / 2
    }
    DotText {
        visible: f.opt("showDate", true)
        text: f.day
        color: card.dim
        cell: Math.min(big.cell * 0.42, fitCell(f.width - 2 * f.pad, f.height * 0.16))
        x: (f.width - width) / 2
        anchors.bottom: parent.bottom; anchors.bottomMargin: f.pad * 0.9
    }
    // the seconds: a red dot, on for one, off for the next
    Rectangle {
        visible: f.opt("showSeconds", true)
        width: Math.max(6, big.cell * 0.8); height: width; radius: width / 2
        color: card.accent
        x: f.width - f.pad * 0.55 - width; y: f.pad * 0.55
        opacity: f.now.getSeconds() % 2 === 0 ? 1 : 0.15
        Behavior on opacity { NumberAnimation { duration: 260; easing.type: Easing.OutCubic } }
    }
}
