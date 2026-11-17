import QtQuick
import "../../core"
import "../../ui"

// Date, Cyberpunk: the day's number big with its split signal, the weekday and month beside it,
// and the week as seven segments with today lit.
FaceBase {
    id: f
    CyberCard {
        id: c; ctx: f.ctx; label: "Date"
        CyberText { id: day; card: c; width: parent.width * 0.42; height: parent.height * 0.78; text: Qt.formatDate(f.now, "dd") }
        Column {
            x: day.width + c.u * 0.06; width: parent.width - x; anchors.verticalCenter: day.verticalCenter
            spacing: c.u * 0.03
            CyberText { card: c; width: parent.width; height: c.u * 0.2; ghosts: false; color: c.neon; text: Qt.formatDate(f.now, "dddd").toUpperCase() }
            CyberText { card: c; width: parent.width; height: c.u * 0.15; ghosts: false; color: c.dim; weight: Font.DemiBold; text: Qt.formatDate(f.now, "MMMM yyyy").toUpperCase() }
        }
        Row {
            anchors.bottom: parent.bottom; width: parent.width; height: Math.max(3, c.u * 0.035); spacing: c.u * 0.02
            Repeater {
                model: 7
                Rectangle {
                    required property int index
                    width: (parent.width - parent.spacing * 6) / 7; height: parent.height
                    color: index === (f.now.getDay() + 6) % 7 ? c.neon : Qt.alpha(c.edge, 0.2)
                }
            }
        }
    }
}
