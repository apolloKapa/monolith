import Quickshell
import Quickshell.Io
import QtQuick

// ram / cpu / gpu / uptime, fed by the sysstats-feed script
Row {
    id: root
    spacing: Theme.spacing

    property string ram: "-"
    property string cpu: "-"
    property string gpu: "-"
    property string up: "-"

    function fmtUp(s) {
        var d = Math.floor(s / 86400), h = Math.floor(s % 86400 / 3600), m = Math.floor(s % 3600 / 60)
        return (d > 0 ? d + "d " : "") + h + "h " + m + "m"
    }

    Process {
        running: true
        command: ["sysstats-feed"]
        stdout: SplitParser {
            onRead: line => {
                var p = line.trim().split(" ")
                if (p.length < 7) return
                root.ram = p[0] + "/" + p[1] + "G"
                root.cpu = p[2] + "% " + p[3] + "°C"
                root.gpu = p[4] + "% " + p[5] + "°C"
                root.up = root.fmtUp(parseInt(p[6]))
            }
        }
    }

    // one label + value pair, brightens on hover
    component Stat: Item {
        id: st
        property string label: ""
        property string value: ""
        implicitWidth: pair.implicitWidth
        implicitHeight: pair.implicitHeight
        opacity: hov.containsMouse ? 1.0 : 0.85
        Behavior on opacity { NumberAnimation { duration: Theme.animFast } }

        Row {
            id: pair
            spacing: 6
            Text { text: st.label; color: Theme.dim; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
            Text { text: st.value; color: Theme.text; font.family: Theme.font; font.pixelSize: Theme.fontSmall }
        }
        MouseArea { id: hov; anchors.fill: parent; hoverEnabled: true; acceptedButtons: Qt.NoButton }
    }

    component Divider: Rectangle {
        width: Theme.borderWidth
        height: 18
        color: Theme.border
    }

    Stat { label: "ram"; value: root.ram; anchors.verticalCenter: parent.verticalCenter }
    Divider { anchors.verticalCenter: parent.verticalCenter }
    Stat { label: "cpu"; value: root.cpu; anchors.verticalCenter: parent.verticalCenter }
    Divider { anchors.verticalCenter: parent.verticalCenter }
    Stat { label: "gpu"; value: root.gpu; anchors.verticalCenter: parent.verticalCenter }
    Divider { anchors.verticalCenter: parent.verticalCenter }
    Stat { label: "up"; value: root.up; anchors.verticalCenter: parent.verticalCenter }
}
