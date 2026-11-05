import QtQuick
import QtQuick.Effects
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Mpris
import "../core"
import "../ui"

// The lock screen: the wallpaper softly blurred, a large clock, and you with a password pill
// at the bottom (the same pill as the hub's search). Shakes on a wrong password.
WlSessionLock {
    id: lock
    locked: LockState.locked

    WlSessionLockSurface {
        id: surface
        color: Theme.card

        Image {
            id: wp
            anchors.fill: parent
            source: Wall.url(Wall.path)
            fillMode: Image.PreserveAspectCrop
            sourceSize: Qt.size(surface.width / 2, surface.height / 2)
            visible: false
        }
        MultiEffect {
            anchors.fill: parent
            source: wp
            blurEnabled: true
            blur: 1.0
            blurMax: 48
            saturation: -0.1
        }
        Rectangle { anchors.fill: parent; color: Qt.alpha(Theme.card, 0.45) }

        SystemClock { id: clock; precision: SystemClock.Seconds }
        property real enter: 0
        Component.onCompleted: enter = 1
        Behavior on enter { NumberAnimation { duration: 700; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.enterCurve } }

        // the clock, upper left third
        Column {
            x: parent.width * 0.08
            y: parent.height * 0.14
            opacity: surface.enter
            transform: Translate { y: 30 * (1 - surface.enter) }
            Label { text: Qt.formatDate(clock.date, "dddd, d MMMM"); font.pixelSize: 26; color: Theme.text }
            Label { text: Qt.formatTime(clock.date, "HH:mm"); font.pixelSize: 168; font.weight: Font.Light; color: Theme.text }
        }

        // now playing, top right
        readonly property var player: Mpris.players.values.find(p => p.isPlaying) || null
        Rectangle {
            visible: !!surface.player && Store.get("lock.media", true) !== false
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.margins: 40
            width: 360
            height: 84
            radius: Theme.corner(height, 8)
            color: Qt.alpha(Theme.card, 0.85)
            Row {
                anchors.fill: parent
                anchors.margins: 10
                spacing: 12
                Rectangle {
                    width: 64; height: 64
                    radius: Theme.corner(64, 4)
                    color: Theme.control
                    clip: true
                    Image { anchors.fill: parent; source: surface.player ? (surface.player.trackArtUrl || "") : ""; fillMode: Image.PreserveAspectCrop }
                }
                Column {
                    width: parent.width - 64 - 12 - 50
                    anchors.verticalCenter: parent.verticalCenter
                    Label { width: parent.width; text: surface.player ? surface.player.trackTitle : ""; strong: true }
                    Label { width: parent.width; text: surface.player ? surface.player.trackArtist : ""; muted: true; font.pixelSize: Theme.sizeSmall }
                }
                Pressable {
                    width: 40; height: 40
                    anchors.verticalCenter: parent.verticalCenter
                    color: Theme.accent
                    ink: Theme.onAccent
                    onClicked: surface.player.togglePlaying()
                    Icon { anchors.centerIn: parent; name: "pause"; size: 22; filled: true; color: Theme.onAccent }
                }
            }
        }

        // you and the password
        Column {
            id: who
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom
            anchors.bottomMargin: parent.height * 0.12
            spacing: 14
            opacity: surface.enter
            transform: Translate { y: 40 * (1 - surface.enter) }

            readonly property string avatar: (Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face")
            Rectangle {
                anchors.horizontalCenter: parent.horizontalCenter
                width: 96; height: 96
                radius: Theme.corner(96, 16)
                color: Theme.accentContainer
                clip: true
                Image { id: av; anchors.fill: parent; source: Wall.url(who.avatar); fillMode: Image.PreserveAspectCrop; sourceSize: Qt.size(192, 192) }
                Icon { anchors.centerIn: parent; visible: av.status !== Image.Ready; name: "person"; size: 48; filled: true; color: Theme.onAccentContainer }
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                text: Quickshell.env("USER") || ""
                font.pixelSize: Theme.sizeTitle + 2
                strong: true
            }

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 380
                height: 56
                radius: Theme.corner(height)
                color: Qt.alpha(Theme.containerHigh, 0.92)
                property real shake: 0
                transform: Translate { x: Math.sin(field.shake * Math.PI * 6) * 14 * (1 - field.shake) }
                NumberAnimation { id: shakeAnim; target: field; property: "shake"; from: 0; to: 1; duration: 480 }
                Connections { target: LockState; function onFailed() { shakeAnim.restart(); pw.text = ""; } }

                Bubble {
                    id: lb
                    x: 8
                    anchors.verticalCenter: parent.verticalCenter
                    size: 40
                    icon: LockState.busy ? "hourglass_top" : "lock"
                    on: true
                }
                TextInput {
                    id: pw
                    anchors.left: lb.right; anchors.leftMargin: 14
                    anchors.right: parent.right; anchors.rightMargin: 18
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
                        text: LockState.message !== "" ? LockState.message : "Password"
                        color: LockState.message !== "" ? Theme.danger : Theme.subtext
                        font.pixelSize: Theme.sizeTitle - 1
                    }
                }
                Component.onCompleted: pw.forceActiveFocus()
            }
        }
    }
}
