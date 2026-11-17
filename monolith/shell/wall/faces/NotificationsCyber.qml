import QtQuick
import "../../core"
import "../../ui"

// Notifications, Cyberpunk: INBOX. The latest as log lines: [time] APP, then what it said.
FaceBase {
    id: f
    CyberCard {
        id: c; ctx: f.ctx; label: "Inbox // " + Notifs.list.length
        Column {
            anchors.fill: parent
            spacing: c.u * 0.03
            readonly property real rowH: Math.max(14, c.u * 0.12)
            Repeater {
                model: Notifs.list.slice(0, Math.max(1, Math.floor(parent.height / (parent.rowH + parent.spacing))))
                Row {
                    required property var modelData
                    width: parent.width; height: parent.rowH
                    spacing: c.u * 0.03
                    Text { renderType: Text.CurveRendering; height: parent.height; verticalAlignment: Text.AlignVCenter; text: ">"; color: c.edge; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.75 }
                    Text { renderType: Text.CurveRendering; height: parent.height; verticalAlignment: Text.AlignVCenter; text: String(parent.modelData.appName || "").toUpperCase(); color: c.neon; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.75 }
                    Text { renderType: Text.CurveRendering; width: parent.width - x; height: parent.height; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; text: parent.modelData.summary || ""; color: c.ink; font.family: c.fam; font.weight: Font.DemiBold; font.pixelSize: parent.height * 0.75 }
                }
            }
        }
        Text { anchors.centerIn: parent; visible: Notifs.list.length === 0; renderType: Text.CurveRendering; text: "NO MESSAGES"; color: c.dim; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: Math.max(10, c.u * 0.12) }
    }
}
