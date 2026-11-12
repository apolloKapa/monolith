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

        // ── your desktop as it was when you locked (LockState takes the picture): the lock screen
        // starts as it and blurs into itself, and unlocking goes back to it ──
        readonly property string shotName: surface.screen ? surface.screen.name : ""
        Image {
            id: shot
            anchors.fill: parent
            visible: false
            asynchronous: false
            cache: false
            // (each lock makes new surfaces, so with no cache it's always the fresh picture)
            source: LockState.hasShot && surface.shotName !== "" ? "file://" + LockState.shotFor(surface.shotName) : ""
        }
        MultiEffect {
            anchors.fill: parent
            visible: shot.status === Image.Ready
            source: shot
            blurEnabled: true
            blur: surface.enter
            blurMax: 64
            saturation: -0.9 * surface.enter
            brightness: -0.08 * surface.enter
        }
        Item {
            anchors.fill: parent
            // over the picture it fades in (and out when unlocking); without one it's just there
            opacity: shot.status === Image.Ready ? surface.enter : 1
            // ── the wallpaper, blurred and faded ──
            Image {
                id: wp
                anchors.fill: parent
                source: Wall.still(Wall.pathFor(surface.screen ? surface.screen.name : ""))
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

        }

        SystemClock { id: clock; precision: SystemClock.Seconds }
        // 0 → 1 as it locks, back to 0 as it unlocks (then the session unlocks)
        property real enter: 0
        Component.onCompleted: enter = 1
        Connections { target: LockState; function onUnlockingChanged() { surface.enter = LockState.unlocking ? 0 : 1; } }
        Behavior on enter {
            NumberAnimation {
                duration: LockState.unlocking ? Theme.ms(650) : Theme.ms(800)
                easing.type: Easing.BezierSpline
                easing.bezierCurve: LockState.unlocking ? Theme.exitCurve : Theme.enterCurve
            }
        }

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
            // (the media widget only while Lock & idle → Media on the lock screen is on)
            model: WidgetLayout.on("lock", surface.shotName).filter(i => i.type !== "media" || Store.get("lock.media", true) !== false)
            WidgetFace {
                required property var modelData
                item: WidgetLayout.fitted(modelData, surface.height)
                width: implicitWidth
                height: implicitHeight
                x: Math.max(0, Math.min(modelData.x * surface.width, surface.width - width))
                y: Math.max(0, Math.min(modelData.y * surface.height, surface.height - height))
                opacity: surface.enter
                scale: Theme.popScale + (1 - Theme.popScale) * surface.enter
            }
        }

        // a screen without the password box still takes the typing (the keyboard may be here)
        TextInput {
            id: ghost
            // (invisible items can't have the keyboard: a see-through 1 px one instead)
            width: 1; height: 1; opacity: 0
            enabled: !who.visible && !LockState.busy
            focus: !who.visible
            echoMode: TextInput.Password
            readOnly: LockState.unlocking
            onTextChanged: if (LockState.typed !== text) LockState.typed = text
            onAccepted: if (text !== "") LockState.tryPassword(text)
            Connections { target: LockState; function onTypedChanged() { if (ghost.text !== LockState.typed) ghost.text = LockState.typed; } }
            Component.onCompleted: if (!who.visible) forceActiveFocus()
        }
        // there: what's been typed (as dots) or what went wrong, and where the box is
        Rectangle {
            visible: !who.visible
            anchors.horizontalCenter: parent.horizontalCenter
            anchors.bottom: parent.bottom; anchors.bottomMargin: parent.height * 0.06
            width: noteRow.implicitWidth + 32; height: 44; radius: Theme.corner(48, 8) * 44 / 64
            color: Qt.alpha(Theme.frame, 0.85)
            opacity: surface.enter
            Row {
                id: noteRow
                anchors.centerIn: parent; spacing: 10
                Icon { name: "lock"; size: 18; filled: true; color: LockState.message !== "" ? Theme.danger : Theme.accent; anchors.verticalCenter: parent.verticalCenter }
                Label {
                    anchors.verticalCenter: parent.verticalCenter
                    width: Math.min(implicitWidth, surface.width - 120)
                    text: LockState.message !== "" ? LockState.message
                        : LockState.typed !== "" ? "●".repeat(Math.min(24, LockState.typed.length)) + "   Enter to unlock"
                        : "Type your password (the box is on " + WidgetLayout.passScreen + ")"
                    color: LockState.message !== "" ? Theme.danger : Theme.text
                }
            }
        }
        // ── the password pill, your picture inside it, the power buttons under it. Where the
        // widget editor put it (Lock screen tab: drag it; lock.password = its middle, as parts of
        // the screen), else at the bottom in the middle ──
        Column {
            id: who
            // only on the screen picked for it (Lock & idle → Password box on), else on every one
            visible: WidgetLayout.passOn(surface.shotName)
            readonly property var at: WidgetLayout.passAt(surface.shotName)
            readonly property bool placed: !!at
            x: Math.max(0, Math.min(parent.width - width, placed ? at.x * parent.width - width / 2 : (parent.width - width) / 2))
            y: Math.max(0, Math.min(parent.height - height, placed ? at.y * parent.height - height / 2 : parent.height * 0.92 - height))
            spacing: 14
            // fades in with a little zoom (and out when unlocking)
            opacity: surface.enter
            scale: Theme.popScale + (1 - Theme.popScale) * surface.enter
            transformOrigin: placed ? Item.Center : Item.Bottom
            readonly property string avatar: Store.get("general.avatar", "") || ((Prefs.raw.general && Prefs.raw.general.avatarPath) ? Prefs.raw.general.avatarPath : (Quickshell.env("HOME") + "/.face"))

            Rectangle {
                id: field
                anchors.horizontalCenter: parent.horizontalCenter
                width: 420
                height: 64
                // the → button's corners plus the 8 px gap around it (a round pill with round
                // buttons, a squarer one with squarer buttons: the button never pokes out)
                radius: Theme.corner(48, 8)
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
                    clip: true
                    readOnly: LockState.unlocking
                    color: Theme.text
                    font.family: Theme.fontFamily
                    font.pixelSize: Theme.sizeTitle
                    focus: who.visible
                    enabled: !LockState.busy
                    onAccepted: if (text !== "") LockState.tryPassword(text)
                    // the same typing on every screen
                    onTextChanged: if (LockState.typed !== text) LockState.typed = text
                    Connections { target: LockState; function onTypedChanged() { if (pw.text !== LockState.typed) pw.text = LockState.typed; } }
                    Label {
                        anchors.fill: parent
                        verticalAlignment: Text.AlignVCenter
                        visible: pw.text === ""
                        elide: Text.ElideRight
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
                Component.onCompleted: if (who.visible) pw.forceActiveFocus()
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 10
                Repeater {
                    // [icon, action, its name]: restart and power off have to be held for a
                    // second: the button opens up with its name and fills red from the left
                    model: [["bedtime", "suspend", "Sleep"], ["restart_alt", "reboot", "Restart"], ["power_settings_new", "poweroff", "Power off"]]
                    Pressable {
                        id: lb
                        required property var modelData
                        readonly property bool held: modelData[1] !== "suspend"
                        property real level: 0
                        property bool done: false
                        readonly property bool open: held && (pressed || level > 0.001)
                        width: open ? lbt.implicitWidth + 56 : 44; height: 44
                        Behavior on width { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } }
                        color: Qt.alpha(Theme.frame, 0.75)
                        onPressedChanged: {
                            if (!held || done) return;
                            if (pressed) { lbDrain.stop(); lbFill.duration = Math.max(1, 1000 * (1 - level)); lbFill.restart(); }
                            else if (level < 1) { lbFill.stop(); lbDrain.duration = Theme.ms(320 * level + 1); lbDrain.restart(); }
                        }
                        onClicked: if (!held) Power.run(modelData[1])
                        // a real second, whatever the animation speed
                        NumberAnimation {
                            id: lbFill
                            target: lb; property: "level"; to: 1
                        }
                        NumberAnimation { id: lbDrain; target: lb; property: "level"; to: 0; easing.type: Easing.OutCubic }
                        // full: it happens right then
                        onLevelChanged: if (held && level >= 0.999 && !done && lbFill.running) { done = true; Power.run(modelData[1]); lbUndo.restart(); }
                        Timer { id: lbUndo; interval: 2500; onTriggered: { lb.done = false; lbDrain.duration = Theme.ms(320 * lb.level + 1); lbDrain.restart(); } }
                        Row {
                            id: lbFace
                            anchors.centerIn: parent
                            spacing: 8
                            Icon { name: lb.modelData[0]; size: 20; anchors.verticalCenter: parent.verticalCenter }
                            Text { id: lbt; visible: lb.open; text: "Hold to " + lb.modelData[2].toLowerCase(); color: Theme.text; font.family: Theme.fontFamily; font.pixelSize: 13; font.weight: Font.Bold; anchors.verticalCenter: parent.verticalCenter }
                        }
                        // the red, cut to the round button; the icon and name light on it
                        Item {
                            anchors.fill: parent
                            visible: lb.level > 0.001
                            layer.enabled: visible
                            layer.effect: MultiEffect { maskEnabled: true; maskSource: lbMask; maskThresholdMin: 0.5; maskSpreadAtMin: 1.0 }
                            Rectangle { width: parent.width * lb.level; height: parent.height; color: Theme.danger }
                            Item {
                                width: parent.width * lb.level; height: parent.height
                                clip: true
                                Row {
                                    x: lbFace.x; y: lbFace.y
                                    spacing: 8
                                    Icon { name: lb.modelData[0]; size: 20; filled: true; color: Theme.m("on_error", "#ffffff"); anchors.verticalCenter: parent.verticalCenter }
                                    Text { visible: lb.open; text: lbt.text; color: Theme.m("on_error", "#ffffff"); font: lbt.font; anchors.verticalCenter: parent.verticalCenter }
                                }
                            }
                        }
                        Rectangle { id: lbMask; anchors.fill: parent; radius: lb.radius; visible: false; layer.enabled: true }
                    }
                }
            }
        }
    }
}
