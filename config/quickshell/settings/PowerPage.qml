import QtQuick
import QtQuick.Layouts
import Quickshell

Item {
    id: pg
    property string armed: ""

    Timer { id: tm; interval: 3000; onTriggered: pg.armed = "" }
    function act(id, cmd) {
        if (armed === id) {
            armed = ""
            Quickshell.execDetached(cmd)
        } else {
            armed = id
            tm.restart()
        }
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 10
        Lbl { text: "SESSION   (click twice to confirm)" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn { label: "Lock"; onClicked: Quickshell.execDetached(["swaylock"]) }
            Btn { label: pg.armed === "sleep" ? "Sure?" : "Suspend"; active: pg.armed === "sleep"; onClicked: pg.act("sleep", ["systemctl", "suspend"]) }
            Btn { label: pg.armed === "out" ? "Sure?" : "Log out"; active: pg.armed === "out"; onClicked: pg.act("out", ["niri", "msg", "action", "quit", "--skip-confirmation"]) }
            Btn { label: pg.armed === "reboot" ? "Sure?" : "Reboot"; active: pg.armed === "reboot"; onClicked: pg.act("reboot", ["systemctl", "reboot"]) }
            Btn { label: pg.armed === "off" ? "Sure?" : "Shut down"; active: pg.armed === "off"; onClicked: pg.act("off", ["systemctl", "poweroff"]) }
        }
        Lbl { text: "MONITORS" }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            Btn { label: "Turn screens off"; onClicked: Quickshell.execDetached(["niri", "msg", "action", "power-off-monitors"]) }
        }
        Item { Layout.fillHeight: true }
    }
}
