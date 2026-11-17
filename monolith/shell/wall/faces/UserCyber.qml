import QtQuick
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// You, Cyberpunk: OPERATOR. Your picture in a cut-corner frame, your name with its split signal,
// the machine and how long it's been up.
FaceBase {
    id: f
    readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))
    property string uptime: ""
    FileView { id: upFile; path: "/proc/uptime"; blockLoading: true }
    Timer { interval: 60000; repeat: true; running: f.live; triggeredOnStart: true
        onTriggered: { upFile.reload(); const t = Math.floor(parseFloat(upFile.text())); if (!isNaN(t)) f.uptime = Wellbeing.fmt(t); } }
    CyberCard {
        id: c; ctx: f.ctx; label: "Operator"
        Item {
            id: pic
            width: Math.min(parent.height, parent.width * 0.38); height: width
            anchors.verticalCenter: parent.verticalCenter
            Image { anchors.fill: parent; anchors.margins: c.line * 2; source: Wall.url(f.avatar); fillMode: Image.PreserveAspectCrop; asynchronous: true; smooth: true }
            Rectangle { anchors.fill: parent; color: "transparent"; border.width: c.line; border.color: c.edge }
            Rectangle { x: parent.width - width; y: 0; width: parent.width * 0.35; height: Math.max(2, c.u * 0.018); color: c.neon }
        }
        Column {
            x: pic.width + c.u * 0.06; width: parent.width - x; anchors.verticalCenter: parent.verticalCenter
            spacing: c.u * 0.03
            CyberText { card: c; width: parent.width; height: c.u * 0.22; text: (Quickshell.env("USER") || "user").toUpperCase() }
            CyberText { card: c; width: parent.width; height: c.u * 0.12; ghosts: false; color: c.neon; text: "NODE // " + String(Quickshell.env("HOSTNAME") || "local").toUpperCase() }
            CyberText { card: c; width: parent.width; height: c.u * 0.11; ghosts: false; color: c.dim; weight: Font.DemiBold; text: "UPTIME " + f.uptime.toUpperCase() }
        }
    }
}
