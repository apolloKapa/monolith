import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import "../../core"
import "../../ui"

// You: glass; your round picture with two buttons beside it (your name: Settings; Lock), and sleep,
// restart and power off underneath (one, two and three parts wide). Hold one: it fills from the
// bottom with a wave in its colour and does it when full; let go early and it drains back.
FaceBase {
    id: f
    readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))
    readonly property real r: Theme.corner(80, 14)
    readonly property real small: Math.min(Theme.corner(80, 8), 8)
    Glass { anchors.fill: parent; ctx: f.ctx; radius: f.r }
    Fit {
        dw: 280; dh: 150
        ColumnLayout {
            anchors.fill: parent
            anchors.margins: 10
            spacing: 8
            RowLayout {
                Layout.fillWidth: true; Layout.fillHeight: true
                spacing: 10
                Avatar { Layout.preferredWidth: 70; Layout.preferredHeight: 70; size: 70; fallback: Theme.control; iconColor: Theme.text }
                ColumnLayout {
                    Layout.fillWidth: true; Layout.fillHeight: true
                    spacing: 6
                    Repeater {
                        model: [["person", Quickshell.env("USER") || "You", Theme.text, "settings"], ["lock", "Lock", Theme.accent, "lock"]]
                        Rectangle {
                            id: qb
                            required property var modelData
                            Layout.fillWidth: true; Layout.preferredHeight: 32
                            radius: f.small
                            color: Qt.alpha(qma.containsMouse ? Theme.containerHigh : Theme.control, 0.85)
                            Behavior on color { ColorAnimation { duration: Theme.ms(200); easing.type: Easing.OutCubic } }
                            Row {
                                x: 10; anchors.verticalCenter: parent.verticalCenter
                                width: parent.width - 20
                                spacing: 8
                                Icon { name: qb.modelData[0]; size: 15; filled: true; color: qb.modelData[2]; anchors.verticalCenter: parent.verticalCenter }
                                Text { width: parent.width - 23; elide: Text.ElideRight; text: qb.modelData[1]; color: qb.modelData[2]; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                            }
                            MouseArea {
                                id: qma
                                anchors.fill: parent
                                hoverEnabled: true
                                enabled: f.live
                                cursorShape: Qt.PointingHandCursor
                                onClicked: qb.modelData[3] === "lock" ? LockState.lock() : HubState.openSettings("appearance", "")
                            }
                        }
                    }
                }
            }
            RowLayout {
                Layout.fillWidth: true; Layout.preferredHeight: 36
                spacing: 6
                Repeater {
                    // [command, icon, share of the row, colour]
                    model: [["suspend", "bedtime", 1, "#89b4fa"], ["reboot", "restart_alt", 2, "#fab387"], ["poweroff", "power_settings_new", 3, "#f38ba8"]]
                    Rectangle {
                        id: act
                        required property var modelData
                        property bool auto: false        // clicked: filling by itself
                        Layout.fillWidth: true; Layout.fillHeight: true
                        Layout.preferredWidth: modelData[2]
                        radius: f.small
                        clip: true
                        color: Qt.alpha(ma.containsMouse ? Theme.containerHigh : Theme.control, 0.85)
                        Behavior on color { ColorAnimation { duration: Theme.ms(250); easing.type: Easing.OutCubic } }
                        scale: ma.pressed ? 0.98 - 0.01 * modelData[2] : (ma.containsMouse ? 1.02 : 1)
                        Behavior on scale { NumberAnimation { duration: Theme.ms(400); easing.type: Easing.OutQuart } }
                        property real level: 0
                        property bool done: false
                        // held, it fills up sideways from the left (a whole second: full = it happens)
                        Rectangle { width: act.width * act.level; height: act.height; radius: act.radius; color: act.modelData[3]; visible: act.level > 0.001 }
                        Rectangle { id: flash; anchors.fill: parent; radius: act.radius; color: "#ffffff"; opacity: 0 }
                        Icon { anchors.centerIn: parent; name: act.modelData[1]; size: 16; color: ma.containsMouse ? Theme.text : Theme.subtext }
                        // the icon turns dark where it's filled
                        Item {
                            width: act.width * act.level; height: act.height
                            clip: true
                            Icon { x: (act.width - width) / 2; y: (act.height - height) / 2; name: act.modelData[1]; size: 16; color: "#15161a" }
                        }
                        // full, still held: it happens (checked when the fill finishes: see hub/cc/Controls.qml)
                        NumberAnimation { id: filling; target: act; property: "level"; to: 1
                            onFinished: if (act.level >= 0.999 && !act.done && (ma.pressed || act.auto)) { act.auto = false; act.done = true; flashAnim.start(); Power.run(act.modelData[0]); reset.start(); } }
                        NumberAnimation { id: draining; target: act; property: "level"; to: 0; duration: Theme.ms(500); easing.type: Easing.OutCubic }
                        NumberAnimation { id: flashAnim; target: flash; property: "opacity"; from: 0.6; to: 0; duration: Theme.ms(500); easing.type: Easing.OutExpo }
                        Timer { id: reset; interval: 1500; onTriggered: { act.done = false; draining.start(); } }
                        MouseArea {
                            id: ma
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: f.live
                            cursorShape: act.done ? Qt.ArrowCursor : Qt.PointingHandCursor
                            // hold it, or click once and it fills by itself (a second click cancels)
                            property real downAt: 0
                            onPressed: if (!act.done && !act.auto) { downAt = Date.now(); draining.stop(); filling.duration = 1000 * (1 - act.level) + 1; filling.restart(); }
                            onReleased: {
                                if (act.done) return;
                                if (act.auto) { act.auto = false; filling.stop(); draining.start(); return; }
                                // a quick click: carry on by itself
                                if (Date.now() - downAt < 300 && act.level < 1) { act.auto = true; return; }
                                if (act.level < 1) { filling.stop(); draining.start(); }
                            }
                            onCanceled: if (!act.done && !act.auto) { filling.stop(); draining.start(); }
                        }
                    }
                }
            }
        }
    }
}
