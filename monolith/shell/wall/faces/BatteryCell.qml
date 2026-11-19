import QtQuick
import "../../core"
import "../../ui"

// Battery, Cell: the classic battery drawn in outline, five blocks inside that fill with the
// charge (the last one as far as it has got), and the percentage over them. Charging, the blocks
// light one after another.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real bw: Math.min(f.width * 0.86, f.height * 2.3)
    readonly property real bh: bw / 2.3
    readonly property real t: Math.max(2, bh * 0.07)
    property int beat: 0
    Timer { interval: 420; repeat: true; running: f.live && b.charging && b.level < 0.995; onTriggered: f.beat = (f.beat + 1) % 6 }
    Item {
        anchors.centerIn: parent
        width: f.bw; height: f.bh
        Rectangle {
            id: shell
            width: parent.width * 0.93; height: parent.height
            radius: Theme.rnd(height * 0.2)
            color: "transparent"
            border.width: f.t; border.color: f.mainC
            Row {
                id: cells
                readonly property real pad: f.t * 2.2
                x: pad; y: pad
                width: parent.width - 2 * pad; height: parent.height - 2 * pad
                spacing: f.t
                Repeater {
                    model: 5
                    Rectangle {
                        required property int index
                        // how full this block is (0 … 1)
                        readonly property real k: Math.max(0, Math.min(1, b.level * 5 - index))
                        width: (cells.width - 4 * cells.spacing) / 5; height: cells.height
                        radius: Theme.rnd(height * 0.14)
                        color: Qt.alpha(f.mainC, 0.12)
                        Rectangle {
                            width: parent.width * parent.k; height: parent.height
                            radius: parent.radius
                            color: b.color
                            opacity: b.charging && f.beat === index + 1 ? 1 : (b.charging ? 0.7 : 1)
                            Behavior on opacity { NumberAnimation { duration: Theme.ms(300) } }
                            Behavior on width { NumberAnimation { duration: Theme.ms(500); easing.type: Easing.OutCubic } }
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                renderType: Text.CurveRendering
                text: b.present ? Math.round(b.level * 100) + "%" : "—"
                color: Theme.text
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.45)
                font.family: Theme.fontFamily; font.weight: Font.Bold
                font.pixelSize: Math.max(10, f.bh * 0.38)
            }
        }
        // the terminal
        Rectangle {
            x: shell.width + f.t * 0.6; anchors.verticalCenter: parent.verticalCenter
            width: parent.width * 0.045; height: parent.height * 0.36
            radius: Theme.rnd(width * 0.5)
            color: f.mainC
        }
    }
}
