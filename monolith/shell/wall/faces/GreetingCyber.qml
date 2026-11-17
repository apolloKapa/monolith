import QtQuick
import Quickshell
import "../../core"
import "../../ui"

// Greeting, Cyberpunk: the hour's greeting with its split signal and a blinking block cursor,
// and what's waiting under it.
FaceBase {
    id: f
    readonly property int h: f.now.getHours()
    CyberCard {
        id: c; ctx: f.ctx; label: "Link established"
        CyberText { id: g; card: c; width: parent.width - cur.width - c.u * 0.03; height: parent.height * 0.55
            text: (f.h < 5 ? "Good night" : f.h < 12 ? "Good morning" : f.h < 18 ? "Good afternoon" : "Good evening") + ", " + (Quickshell.env("USER") || "") }
        Rectangle {
            id: cur
            anchors.left: g.left; anchors.leftMargin: Math.min(g.width, g.implicitTextWidth) + c.u * 0.02
            anchors.verticalCenter: g.verticalCenter
            width: c.u * 0.06; height: g.height * 0.6; color: c.neon
            SequentialAnimation on opacity { running: f.live && Theme.animOn; loops: Animation.Infinite; NumberAnimation { to: 0; duration: 1; } PauseAnimation { duration: 500 } NumberAnimation { to: 1; duration: 1 } PauseAnimation { duration: 500 } }
        }
        CyberText { anchors.bottom: parent.bottom; card: c; width: parent.width; height: parent.height * 0.22; ghosts: false; color: c.dim; weight: Font.DemiBold
            text: (Notifs.list.length > 0 ? Notifs.list.length + " messages waiting" : "No new messages").toUpperCase() }
    }
}
