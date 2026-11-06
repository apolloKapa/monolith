import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import "../../core"
import "../../ui"

// You: glass; your picture, your name, the computer and how long it's been up, and sleep,
// restart and power off (hold one for a moment to do it).
FaceBase {
    id: f
    readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))
    property string uptime: ""
    FileView { id: host; path: "/etc/hostname" }
    FileView { id: up; path: "/proc/uptime" }
    Timer {
        interval: 60000; repeat: true; triggeredOnStart: true; running: f.live
        onTriggered: {
            up.reload();
            const s = Math.floor(parseFloat((up.text() || "0").split(" ")[0]));
            const d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60);
            f.uptime = (d > 0 ? d + "d " : "") + (h > 0 ? h + "h " : "") + m + "m";
        }
    }
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 280; dh: 150
        RowLayout {
            x: 14; y: 14; width: parent.width - 28
            spacing: 12
            Rectangle {
                width: 58; height: 58; radius: Theme.corner(58, 12); color: Theme.accentContainer; clip: true
                Image { id: av; anchors.fill: parent; source: Wall.url(f.avatar); fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(116, 116); visible: false }
                MultiEffect { anchors.fill: parent; source: av; visible: av.status === Image.Ready; maskEnabled: true; maskSource: avm }
                Rectangle { id: avm; anchors.fill: parent; radius: parent.radius; visible: false; layer.enabled: true }
                Icon { anchors.centerIn: parent; visible: av.status !== Image.Ready; name: "person"; filled: true; size: 30; color: Theme.onAccentContainer }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text { Layout.fillWidth: true; elide: Text.ElideRight; text: Quickshell.env("USER") || ""; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 20 }
                Row {
                    spacing: 4
                    Repeater {
                        model: [["computer", (host.text() || "").trim() || "localhost"], ["schedule", f.uptime]]
                        Rectangle {
                            required property var modelData
                            height: 22; width: cr.implicitWidth + 14; radius: Theme.corner(22, 8)
                            color: Qt.alpha(Theme.control, 0.8)
                            Row { id: cr; anchors.centerIn: parent; spacing: 4
                                Icon { name: parent.parent.modelData[0]; size: 13; color: Theme.subtext; anchors.verticalCenter: parent.verticalCenter }
                                Text { text: parent.parent.modelData[1]; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } }
                        }
                    }
                }
            }
        }
        Row {
            x: 14; anchors.bottom: parent.bottom; anchors.bottomMargin: 14
            width: parent.width - 28
            spacing: 6
            Repeater {
                // [command, icon, share of the row, colour]
                model: [["suspend", "bedtime", 1, "#89b4fa"], ["reboot", "restart_alt", 2, "#fab387"], ["poweroff", "power_settings_new", 3, "#f38ba8"]]
                Rectangle {
                    id: act
                    required property var modelData
                    width: (parent.width - 12) * modelData[2] / 6; height: 38
                    radius: Theme.corner(38, 8)
                    color: Qt.alpha(ma.containsMouse ? Theme.containerHigh : Theme.control, 0.85)
                    clip: true
                    property real hold: 0
                    Rectangle { width: parent.width * act.hold; height: parent.height; color: act.modelData[3]; opacity: 0.85 }
                    Icon { anchors.centerIn: parent; name: act.modelData[1]; size: 18; color: act.hold > 0.5 ? "#15161a" : (ma.containsMouse ? act.modelData[3] : Theme.subtext) }
                    NumberAnimation on hold { id: holding; running: false; to: 1; duration: 700; onFinished: if (act.hold >= 1) { Power.run(act.modelData[0]); act.hold = 0; } }
                    MouseArea {
                        id: ma
                        anchors.fill: parent
                        hoverEnabled: true
                        enabled: f.live
                        cursorShape: Qt.PointingHandCursor
                        onPressed: { act.hold = 0; holding.start(); }
                        onReleased: { holding.stop(); act.hold = 0; }
                        onCanceled: { holding.stop(); act.hold = 0; }
                    }
                }
            }
        }
    }
}
