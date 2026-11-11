import QtQuick
import "../../core"

// Date, Dot: the weekday in big dots, the day of the month in red, the month small under it.
FaceBase {
    id: f
    DotCard { id: card; ctx: f.ctx }
    readonly property real pad: Math.min(width, height) * 0.14
    Row {
        id: top
        x: (f.width - width) / 2; y: f.pad
        spacing: wd.cell * 2
        DotText { id: wd; text: Qt.formatDate(f.now, "ddd").toUpperCase(); color: card.ink; offColor: card.off; cell: fitCell((f.width - 2 * f.pad) * 0.6, (f.height - 2 * f.pad) * 0.62) }
        DotText { text: Qt.formatDate(f.now, "d"); color: card.accent; cell: wd.cell }
    }
    DotText {
        text: Qt.formatDate(f.now, "MMMM yyyy").toUpperCase()
        color: card.dim
        cell: Math.min(wd.cell * 0.4, fitCell(f.width - 2 * f.pad, f.height * 0.16))
        x: (f.width - width) / 2
        anchors.bottom: parent.bottom; anchors.bottomMargin: f.pad * 0.8
    }
}
