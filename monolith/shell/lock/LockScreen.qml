import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../core"
import "../ui"
import "../wall"

// The lock screen, in the island's language: the wallpaper blurred under a soft fade, a small
// island hanging from the top (date, weather), a big clock, your latest notifications on the
// left and what's playing on the right, and the password pill (your picture inside it) with
// the power buttons under it. Shakes on a wrong password.
WlSessionLock {
    id: lock
    locked: LockState.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.frame

        // ── the wallpaper, blurred and faded ──
        Image {
            id: wp
            anchors.fill: parent
            source: Wall.path !== "" && !Wall.isVideo(Wall.path) ? Wall.url(Wall.pathFor(surface.screen ? surface.screen.name : "")) : ""
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(surface.width / 2, surface.height / 2)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wp
            blurEnabled: true
            blur: 1.0
            blurMax: 64
            saturation: 0.1
            brightness: -0.08
        }
        Rectangle {
            anchors.fill: parent
            gradient: Gradient {
                GradientStop { position: 0.0; color: Qt.alpha(Theme.frame, 0.25) }
                GradientStop { position: 0.6; color: Qt.alpha(Theme.frame, 0.35) }
                GradientStop { position: 1.0; color: Qt.alpha(Theme.frame, 0.8) }
            }
        }

        SystemClock { id: clock; precision: SystemClock.Seconds }
        property real enter: 0
        Component.onCompleted: enter = 1
        Behavior on enter { NumberAnimation { duration: Theme.ms(800); easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve } }

        // ── the island: locked, the date, the weather ──
        IslandShape {
            id: isl
            anchors.horizontalCenter: parent.horizontalCenter
            y: -Theme.islandH * (1 - surface.enter)
            height: Theme.islandH
            bodyW: islRow.implicitWidth + 2 * Theme.islandPad + 10
            r: height / 2
            Row {
                id: islRow
                anchors.centerIn: parent
                spacing: 10
                Icon { name: "lock"; size: 17; filled: true; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { text: Qt.formatDate(clock.date, "dddd d MMMM"); strong: true; anchors.verticalCenter: parent.verticalCenter }
                Icon { visible: Weather.ready; name: Weather.ready ? Weather.icon(Weather.current.code, Weather.current.day) : ""; size: 17; color: Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label { visible: Weather.ready; text: Weather.ready ? Math.round(Weather.current.temp) + Weather.unit : ""; anchors.verticalCenter: parent.verticalCenter }
            }
        }

        // ── the widgets, where the widget editor put them (its Lock screen tab) ──
        Repeater {
            model: WidgetLayout.on("lock", "")
            WidgetFace {
                required property var modelData
                item: modelData
                width: size[0]
                height: size[1]
                x: Math.max(0, Math.min(modelData.x * surface.width, surface.width - width))
                y: Math.max(0, Math.min(modelData.y * surface.height, surface.height - height))
                opacity: surface.enter
            }
        }

        // ── the password pill, your picture inside it, the power buttons under it ──
        Column {
            id: who
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.08
            spacing: 14
            opacity: surface.enter
            transform: Translate { y: 40 * (1 - surface.enter) }
            readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                height: 64
                radius: height / 2
                color: Qt.alpha(Theme.frame, 0.9)
                border.width: pw.activeFocus ? 2 : 0
                border.color: LockState.message !== "" ? Theme.danger : Theme.accent
                property real shake: 0
                transform: Translate { x: Math.sin(field.shake * Math.PI * 6) * 14 * (1 - field.shake) }
                NumberAnimation { id: shakeAnim; target: field; property: "shake"; from: 0; to: 1; duration: Theme.ms(480); easing.type: Easing.OutCubic }
                Connections { target: LockState; function onFailed() { shakeAnim.restart(); pw.text = ""; } }

                Avatar {
                    id: face
                    x: 8; size: 48
                    anchors.verticalCenter: parent.verticalCenter
                }
                TextInput {
                    id: pw
                    anchors.left: face.right; anchors.leftMargin: 14
                    anchors.right: go.left; anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    echoMode: TextInput.Password
                    passwordCharacter: "●"
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeTitle
                    focus: true
                    enabled: !LockState.busy
                    onAccepted: if (text !== "") LockState.tryPassword(text)
                    Label {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: pw.text === ""
                        text: LockState.message !== "" ? LockState.message : (Quickshell.env("USER") || "") + "  ·  password"
                        color: LockState.message !== "" ? Theme.danger : Theme.subtext
                        font.pixelSize: Theme.sizeTitle - 1
                    }
                }
                Pressable {
                    id: go
                    anchors.right: parent.right; anchors.rightMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    width: 48; height: 48
                    color: Theme.accent; ink: Theme.onAccent
                    onClicked: if (pw.text !== "") LockState.tryPassword(pw.text)
                    Icon { anchors.centerIn: parent; name: LockState.busy ? "hourglass_top" : "arrow_forward"; size: 22; color: Theme.onAccent }
                }
                Component.onCompleted: pw.forceActiveFocus()
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    // [icon, action, its name]: restart and power off need a second click
                    model: [["bedtime", "suspend", "Sleep"], ["restart_alt", "reboot", "Restart"], ["power_settings_new", "poweroff", "Power off"]]
                    Pressable {
                        id: lb
                        required property var modelData
                        property bool armed: false
                        width: armed ? lbt.implicitWidth + 28 : 44; height: 44
                        Behavior on width { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
                        color: armed ? Theme.danger : Qt.alpha(Theme.frame, 0.75)
                        onClicked: {
                            if (modelData[1] !== "suspend" && !armed) { armed = true; lbDisarm.restart(); return; }
                            armed = false;
                            Power.run(modelData[1]);
                        }
                        Timer { id: lbDisarm; interval: 3000; onTriggered: lb.armed = false }
                        Icon { visible: !lb.armed; anchors.centerIn: parent; name: lb.modelData[0]; size: 20 }
                        Text { id: lbt; visible: lb.armed; anchors.centerIn: parent; text: lb.modelData[2] + "?"; color: Theme.m("on_error", "#ffffff"); font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold }
                    }
                }
            }
        }
    }
}
