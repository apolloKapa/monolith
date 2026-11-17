import QtQuick
import "../../core"
import "../../ui"

// Notifications, Cyberpunk: INBOX. The latest as log lines: > APP, then what it said. A new line
// flickers in like a signal finding its channel and slides into place; one that goes glitches out
// sideways; the rest step to make room.
FaceBase {
    id: f
    CyberCard {
        id: c; ctx: f.ctx; label: "Inbox // " + Notifs.list.length
        readonly property real rowH: Math.max(14, c.u * 0.12)
        readonly property real gap: c.u * 0.03
        NotifFeed { id: feed; max: Math.max(1, Math.floor(c.body.height / (c.rowH + c.gap))) }
        ListView {
            anchors.fill: parent
            spacing: c.gap
            interactive: false
            model: feed
            delegate: Row {
                id: row
                required property int nid
                readonly property var n: feed.note(nid)
                width: ListView.view ? ListView.view.width : 0; height: c.rowH
                spacing: c.u * 0.03
                Text { renderType: Text.CurveRendering; height: parent.height; verticalAlignment: Text.AlignVCenter; text: ">"; color: c.edge; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.75 }
                Text { renderType: Text.CurveRendering; height: parent.height; verticalAlignment: Text.AlignVCenter; text: row.n ? String(row.n.appName || "").toUpperCase() : ""; color: c.neon; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: parent.height * 0.75 }
                Text { renderType: Text.CurveRendering; width: parent.width - x; height: parent.height; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight; text: row.n ? (row.n.summary || "") : ""; color: c.ink; font.family: c.fam; font.weight: Font.DemiBold; font.pixelSize: parent.height * 0.75 }
            }
            add: Transition {
                enabled: Theme.animOn
                SequentialAnimation {
                    PropertyAction { property: "opacity"; value: 0.8 }
                    PauseAnimation { duration: Theme.ms(40) }
                    PropertyAction { property: "opacity"; value: 0.1 }
                    PauseAnimation { duration: Theme.ms(40) }
                    PropertyAction { property: "opacity"; value: 1 }
                    PauseAnimation { duration: Theme.ms(50) }
                    PropertyAction { property: "opacity"; value: 0.4 }
                    PauseAnimation { duration: Theme.ms(30) }
                    PropertyAction { property: "opacity"; value: 1 }
                }
                NumberAnimation { property: "x"; from: -c.u * 0.1; duration: Theme.ms(220); easing.type: Easing.OutQuad }
            }
            remove: Transition {
                enabled: Theme.animOn
                SequentialAnimation {
                    PropertyAction { property: "x"; value: c.u * 0.04 }
                    PauseAnimation { duration: Theme.ms(40) }
                    PropertyAction { property: "x"; value: -c.u * 0.03 }
                    PauseAnimation { duration: Theme.ms(40) }
                    ParallelAnimation {
                        NumberAnimation { property: "x"; to: c.u * 0.5; duration: Theme.ms(140); easing.type: Easing.InQuad }
                        NumberAnimation { property: "opacity"; to: 0; duration: Theme.ms(140) }
                    }
                }
            }
            displaced: Transition {
                enabled: Theme.animOn
                NumberAnimation { properties: "x,y"; duration: Theme.ms(220); easing.type: Easing.OutQuad }
                NumberAnimation { property: "opacity"; to: 1; duration: Theme.ms(120) }
            }
        }
        Text { anchors.centerIn: parent; visible: feed.count === 0; renderType: Text.CurveRendering; text: "NO MESSAGES"; color: c.dim; font.family: c.fam; font.weight: Font.Bold; font.pixelSize: Math.max(10, c.u * 0.12) }
    }
}
