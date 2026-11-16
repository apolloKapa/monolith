import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Polkit
import "../core"
import "../ui"

// When an app asks for an administrator password (polkit), a card like the hub's in the
// middle of the screen: what's asking, and the password pill.
Scope {
    PolkitAgent { id: agent }

    PanelWindow {
        id: win
        // asked: shown; answered or cancelled: it fades back out the way it came, then goes
        readonly property bool want: agent.isActive && !!agent.flow
        visible: want || card.opacity > 0.01
        WlrLayershell.namespace: "monolith-polkit"
        WlrLayershell.layer: WlrLayer.Overlay
        WlrLayershell.keyboardFocus: want ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
        exclusionMode: ExclusionMode.Ignore
        anchors { top: true; bottom: true; left: true; right: true }
        color: Qt.alpha("#000000", 0.35 * card.opacity)
        readonly property var flow: agent.flow
        Binding { target: HubState; property: "authOpen"; value: win.want }

        // the card grows in as it's asked and shrinks back out the same way (interrupted halfway,
        // it turns round from where it is)
        onWantChanged: if (want) { pw.text = ""; Qt.callLater(() => pw.forceActiveFocus()); }
        SmoothRect {
            id: card
            anchors.centerIn: parent
            width: 460
            height: col.implicitHeight + 32
            radius: Theme.corner(56, 10)
            color: Theme.card
            border.width: 1
            border.color: Theme.hairline
            opacity: win.want ? 1 : 0
            scale: win.want ? 1 : Theme.popScale
            Behavior on opacity { Anim { kind: win.want ? "enter" : "exit" } }
            Behavior on scale { Anim { kind: win.want ? "enter" : "exit" } }
            property real shake: 0
            transform: Translate { x: Math.sin(card.shake * Math.PI * 6) * 12 * (1 - card.shake) }
            NumberAnimation { id: shakeAnim; target: card; property: "shake"; from: 0; to: 1; duration: Theme.ms(480); easing.type: Easing.OutCubic }
            Connections {
                target: win.flow
                function onAuthenticationFailed() { shakeAnim.restart(); pw.text = ""; Sounds.play("error"); }
            }

            Column {
                id: col
                x: 16; y: 16
                width: parent.width - 32
                spacing: 12
                Row {
                    spacing: 12
                    Bubble { size: 44; icon: "admin_panel_settings"; on: true }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        Label { text: "Authentication needed"; strong: true; font.pixelSize: Theme.sizeTitle }
                        Label { text: win.flow ? (win.flow.actionId || "") : ""; muted: true; font.pixelSize: Theme.sizeSmall }
                    }
                }
                Label { width: parent.width; text: win.flow ? win.flow.message : ""; wrapMode: Text.Wrap; Balance {} }
                SmoothRect {
                    smoothing: 0   // (plain corners in other styles; the Cyberpunk style cuts one)
                    width: parent.width
                    height: 52
                    radius: Theme.corner(height)
                    color: Theme.containerHigh
                    TextInput {
                        Keys.onPressed: e => Sounds.key(e)   // (a sound for each key; never takes it)
                        id: pw
                        clip: true
                        anchors.fill: parent
                        anchors.leftMargin: 18; anchors.rightMargin: 18
                        verticalAlignment: TextInput.AlignVCenter
                        echoMode: win.flow && win.flow.responseVisible ? TextInput.Normal : TextInput.Password
                        color: Theme.text
                        font.family: Theme.fontFamily
                        font.pixelSize: Theme.sizeTitle - 1
                        focus: win.visible
                        onAccepted: if (win.flow && win.flow.isResponseRequired) win.flow.submit(text)
                        Keys.onEscapePressed: if (win.flow) win.flow.cancelAuthenticationRequest()
                        Label {
                            anchors.fill: parent
                            verticalAlignment: Text.AlignVCenter
                            visible: pw.text === ""
                            text: win.flow ? (win.flow.inputPrompt || "Password") : ""
                            muted: true
                        }
                    }
                }
                Label {
                    width: parent.width
                    visible: text !== ""
                    text: win.flow ? win.flow.supplementaryMessage : ""
                    color: win.flow && win.flow.supplementaryIsError ? Theme.danger : Theme.subtext
                    font.pixelSize: Theme.sizeSmall
                    wrapMode: Text.Wrap
                }
                Row {
                    anchors.right: parent.right
                    spacing: 8
                    Pressable {
                        width: 110; height: 42
                        onClicked: if (win.flow) win.flow.cancelAuthenticationRequest()
                        Label { anchors.centerIn: parent; text: "Cancel" }
                    }
                    Pressable {
                        width: 130; height: 42
                        color: Theme.accent; ink: Theme.onAccent
                        onClicked: if (win.flow) win.flow.submit(pw.text)
                        Label { anchors.centerIn: parent; text: "Authenticate"; color: Theme.onAccent; strong: true }
                    }
                }
            }
        }
    }
}
