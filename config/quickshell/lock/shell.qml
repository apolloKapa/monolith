import QtQuick
import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Pam

ShellRoot {
    id: root

    // look: copied from the bar Theme.qml, edit here
    readonly property color backdrop: "#101010"
    readonly property color bg: "#1a1a1a"
    readonly property color field: "#111111"
    readonly property color border: "#555555"
    readonly property color text: "#ffffff"
    readonly property color dim: "#a0a0a0"
    readonly property color bad: "#9b0000"
    readonly property string font: "JetBrains Mono"
    readonly property int fast: 120
    readonly property int normal: 220
    readonly property int slow: 450
    // how long the restart / shut down buttons must be held, in milliseconds
    readonly property int holdTime: 1000

    property string buffer: ""
    property bool checking: false
    property bool failed: false
    property int failCount: 0

    property bool leaving: false
    Timer { id: quitTimer; interval: 350; onTriggered: { lock.locked = false; Qt.quit() } }
    function unlock() {
        leaving = true
        quitTimer.start()
    }
    function submit() {
        if (checking || buffer === "") return
        checking = true
        failed = false
        pam.start()
    }

    SystemClock { id: clock; precision: SystemClock.Seconds }

    // one entry per typed character. Deleting a character does not remove its dot at once:
    // the dot is marked alive: false, plays the appear animation backwards, then removes itself.
    ListModel { id: dotModel }
    function syncDots() {
        var n = root.buffer.length
        var alive = 0
        for (var i = 0; i < dotModel.count; i++)
            if (dotModel.get(i).alive) alive++
        while (alive < n) { dotModel.insert(alive, { alive: true }); alive++ }
        for (var j = dotModel.count - 1; j >= 0 && alive > n; j--) {
            if (dotModel.get(j).alive) { dotModel.setProperty(j, "alive", false); alive-- }
        }
    }

    PamContext {
        id: pam
        configDirectory: "pam"
        config: "password.conf"
        onPamMessage: { if (pam.responseRequired) pam.respond(root.buffer) }
        onCompleted: result => {
            root.checking = false
            if (result === PamResult.Success) {
                root.unlock()
            } else {
                root.failed = true
                root.failCount++
                root.buffer = ""
            }
        }
        onError: { root.checking = false; root.failed = true }
    }

    // test mode: env LOCKTEST=30 qs -c lock  unlocks by itself after 30 seconds
    Timer {
        interval: (Number(Quickshell.env("LOCKTEST")) || 20) * 1000
        running: !!Quickshell.env("LOCKTEST")
        onTriggered: root.unlock()
    }

    WlSessionLock {
        id: lock
        locked: true

        WlSessionLockSurface {
            color: root.backdrop

            Item {
                id: scene
                anchors.fill: parent
                opacity: 0
                Component.onCompleted: { opacity = 1; input.forceActiveFocus() }
                Connections { target: root; function onLeavingChanged() { if (root.leaving) scene.opacity = 0 } }
                Behavior on opacity { NumberAnimation { duration: root.slow; easing.type: Easing.OutCubic } }

                TextInput {
                    id: input
                    width: 1
                    height: 1
                    opacity: 0
                    focus: true
                    echoMode: TextInput.Password
                    onTextChanged: root.buffer = text
                    onAccepted: root.submit()
                    Keys.onEscapePressed: root.buffer = ""
                }
                Connections {
                    target: root
                    function onBufferChanged() { if (input.text !== root.buffer) input.text = root.buffer; root.syncDots() }
                }

                Rectangle {
                    id: box
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: 24
                    width: 420
                    height: col.implicitHeight + 56
                    color: root.bg
                    border.color: root.failed ? root.bad : root.border
                    border.width: 2
                    transform: Translate { id: sh }
                    Behavior on border.color { ColorAnimation { duration: root.normal } }
                    Behavior on anchors.verticalCenterOffset { NumberAnimation { duration: root.slow; easing.type: Easing.OutCubic } }
                    Component.onCompleted: anchors.verticalCenterOffset = 0

                    SequentialAnimation {
                        id: shake
                        NumberAnimation { target: sh; property: "x"; to: -16; duration: 50 }
                        NumberAnimation { target: sh; property: "x"; to: 16; duration: 80 }
                        NumberAnimation { target: sh; property: "x"; to: -10; duration: 70 }
                        NumberAnimation { target: sh; property: "x"; to: 10; duration: 60 }
                        NumberAnimation { target: sh; property: "x"; to: 0; duration: 50 }
                    }
                    Connections { target: root; function onFailCountChanged() { shake.restart() } }

                    Column {
                        id: col
                        anchors.centerIn: parent
                        width: parent.width - 48
                        spacing: 12

                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "dddd, d MMMM yyyy")
                            color: root.dim
                            font.family: root.font
                            font.pixelSize: 15
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Qt.formatDateTime(clock.date, "HH:mm:ss")
                            color: root.text
                            font.family: root.font
                            font.pixelSize: 52
                            font.bold: true
                        }
                        Rectangle { width: parent.width; height: 1; color: root.border }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: Quickshell.env("USER")
                            color: root.dim
                            font.family: root.font
                            font.pixelSize: 14
                        }
                        Rectangle {
                            id: pw
                            width: parent.width
                            height: 44
                            color: root.field
                            clip: true
                            border.width: 1
                            border.color: root.failed ? root.bad : (input.activeFocus ? root.text : root.border)
                            Behavior on border.color { ColorAnimation { duration: root.fast } }
                            Text {
                                visible: root.buffer.length === 0
                                anchors.centerIn: parent
                                text: "password"
                                color: root.dim
                                font.family: root.font
                                font.pixelSize: 14
                            }
                            Row {
                                id: dots
                                spacing: 8
                                anchors.verticalCenter: parent.verticalCenter
                                x: Math.min(14, pw.width - width - 14)
                                Repeater {
                                    model: dotModel
                                    delegate: Rectangle {
                                        id: dot
                                        required property bool alive
                                        required property int index
                                        width: 10
                                        height: 10
                                        color: root.text
                                        scale: 0
                                        // typing: pops in
                                        Component.onCompleted: scale = 1
                                        Behavior on scale { NumberAnimation { duration: root.fast; easing.type: Easing.OutBack } }
                                        // deleting: the same animation backwards, then the dot is removed
                                        onAliveChanged: if (!alive) leave.start()
                                        SequentialAnimation {
                                            id: leave
                                            NumberAnimation { target: dot; property: "scale"; to: 0; duration: root.fast; easing.type: Easing.InBack }
                                            ScriptAction { script: dotModel.remove(dot.index) }
                                        }
                                    }
                                }
                            }
                        }
                        Text {
                            anchors.horizontalCenter: parent.horizontalCenter
                            text: root.checking ? "Checking..." : (root.failed ? "Wrong password" : "Enter to unlock")
                            color: root.failed ? "#d05050" : root.dim
                            font.family: root.font
                            font.pixelSize: 13
                        }
                    }
                }

                // restart / shut down: hold to confirm (same buttons as the bar, bigger)
                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: box.bottom
                    anchors.topMargin: 28
                    spacing: 18

                    HoldButton {
                        iconName: "system-reboot"
                        command: ["systemctl", "reboot"]
                        holdMs: root.holdTime
                        edge: root.border
                        ink: root.text
                        water: root.text
                    }
                    HoldButton {
                        iconName: "system-shutdown"
                        command: ["systemctl", "poweroff"]
                        holdMs: root.holdTime
                        edge: root.border
                        ink: root.text
                        water: root.text
                    }
                }
            }
        }
    }
}
