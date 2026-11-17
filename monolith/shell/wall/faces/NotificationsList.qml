import QtQuick
import "../../core"
import "../../ui"

// Notifications: the latest few as glass rows (app, title), as many as fit. A new one slides down
// into the top as it fades and grows in, the rows under it gliding down to make room; one that goes
// slides off to the side and fades, the rows under it gliding up to close the gap.
FaceBase {
    id: f
    readonly property real rowH: 54
    readonly property int fit: Math.max(1, Math.floor((height + 8) / (rowH + 8)))
    NotifFeed { id: feed; max: f.fit }
    ListView {
        id: lv
        anchors.fill: parent
        spacing: 8
        interactive: false
        clip: false
        model: feed
        delegate: Item {
            id: row
            required property int nid
            required property int index
            readonly property var n: feed.note(nid)
            width: f.width; height: f.rowH
            Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(54, 8); dy: row.y }
            SmoothRect { smoothing: 0; id: nb; x: 8; width: 38; height: 38; radius: Theme.rnd(19); anchors.verticalCenter: parent.verticalCenter; color: Theme.accentContainer
                Icon { anchors.centerIn: parent; name: "notifications"; size: 19; filled: true; color: Theme.onAccentContainer } }
            Column {
                anchors.left: nb.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 14
                anchors.verticalCenter: parent.verticalCenter
                Text { renderType: Text.CurveRendering; width: parent.width; elide: Text.ElideRight; text: row.n ? (row.n.appName || "Notification") : ""; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
                Text { renderType: Text.CurveRendering; width: parent.width; elide: Text.ElideRight; text: row.n ? (row.n.summary || "") : ""; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 14 }
            }
        }
        // a new one: down into its place from a little above, fading and growing in
        add: Transition {
            enabled: Theme.animOn
            ParallelAnimation {
                NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Theme.ms(260); easing.type: Easing.OutCubic }
                NumberAnimation { property: "scale"; from: 0.9; to: 1; duration: Theme.ms(420); easing.type: Easing.OutBack; easing.overshoot: 1.3 }
                NumberAnimation { property: "y"; from: -f.rowH * 0.6; duration: Theme.ms(420); easing.type: Easing.OutCubic }
            }
        }
        // one that goes: off to the side, fading
        remove: Transition {
            enabled: Theme.animOn
            ParallelAnimation {
                NumberAnimation { property: "opacity"; to: 0; duration: Theme.ms(240); easing.type: Easing.InCubic }
                NumberAnimation { property: "x"; to: f.width * 0.35; duration: Theme.ms(280); easing.type: Easing.InCubic }
                NumberAnimation { property: "scale"; to: 0.94; duration: Theme.ms(280); easing.type: Easing.InCubic }
            }
        }
        // the others, gliding to make room or close the gap (and back to whole if caught mid-way)
        displaced: Transition {
            enabled: Theme.animOn
            NumberAnimation { properties: "x,y"; duration: Theme.ms(380); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve }
            NumberAnimation { properties: "opacity,scale"; to: 1; duration: Theme.ms(200) }
        }
    }
    Inked { visible: feed.count === 0; text: "No notifications"; color: Theme.subtext; font.weight: Font.Bold; font.pixelSize: 16 }
}
