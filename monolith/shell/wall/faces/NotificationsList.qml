import QtQuick
import "../../core"
import "../../ui"

// Notifications: the latest few as glass rows (app, title), as many as fit.
FaceBase {
    id: f
    readonly property real rowH: 54
    readonly property int fit: Math.max(1, Math.floor((height + 8) / (rowH + 8)))
    Column {
        width: parent.width
        spacing: 8
        Repeater {
            model: Notifs.list.slice(0, f.fit)
            Item {
                required property var modelData
                required property int index
                width: f.width; height: f.rowH
                Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(54, 8); dy: index * (f.rowH + 8) }
                Rectangle { id: nb; x: 8; width: 38; height: 38; radius: 19; anchors.verticalCenter: parent.verticalCenter; color: Theme.accentContainer
                    Icon { anchors.centerIn: parent; name: "notifications"; size: 19; filled: true; color: Theme.onAccentContainer } }
                Column {
                    anchors.left: nb.right; anchors.leftMargin: 10; anchors.right: parent.right; anchors.rightMargin: 14
                    anchors.verticalCenter: parent.verticalCenter
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.appName || "Notification"; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
                    Text { width: parent.width; elide: Text.ElideRight; text: modelData.summary || ""; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 14 }
                }
            }
        }
    }
    Inked { visible: Notifs.list.length === 0; text: "No notifications"; color: Theme.subtext; font.weight: Font.Bold; font.pixelSize: 16 }
}
