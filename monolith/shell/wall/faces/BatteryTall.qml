import QtQuick
import "../../core"
import "../../ui"

// Battery, Tall: a battery standing up, filling from the bottom, the percentage under it and a
// bolt on it while it charges.
FaceBase {
    id: f
    Battery { id: b }
    readonly property real txt: Math.max(11, Math.min(f.width * 0.26, f.height * 0.12))
    readonly property real bw: Math.min(f.width * 0.62, (f.height - txt * 1.9) * 0.56)
    readonly property real bh: bw * 1.72
    readonly property real t: Math.max(2, bw * 0.07)
    Item {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, (f.height - (f.bh + f.txt * 1.7)) / 2)
        width: f.bw; height: f.bh
        // the terminal
        Rectangle { anchors.horizontalCenter: parent.horizontalCenter; y: 0; width: parent.width * 0.36; height: parent.height * 0.05; radius: Theme.rnd(height / 2); color: f.mainC }
        Rectangle {
            id: shell
            y: parent.height * 0.06
            width: parent.width; height: parent.height * 0.94
            radius: Theme.rnd(width * 0.2)
            color: Qt.alpha(f.mainC, 0.08)
            border.width: f.t; border.color: f.mainC
            Item {
                id: well
                readonly property real pad: f.t * 2
                x: pad; y: pad; width: parent.width - 2 * pad; height: parent.height - 2 * pad
                Rectangle {
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: Math.max(b.present && b.level > 0 ? radius * 2 : 0, parent.height * b.level)
                    radius: Theme.rnd(width * 0.14)
                    color: b.color
                    Behavior on height { NumberAnimation { duration: Theme.ms(600); easing.type: Easing.OutCubic } }
                }
            }
            Icon {
                anchors.centerIn: parent
                visible: b.charging
                name: "bolt"; filled: true; size: f.bw * 0.5
                color: Theme.text
                style: Text.Outline; styleColor: Qt.rgba(0, 0, 0, 0.4)
                SequentialAnimation on opacity {
                    running: f.live && b.charging && b.level < 0.995; loops: Animation.Infinite
                    NumberAnimation { to: 0.45; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }
    }
    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        y: Math.max(0, (f.height - (f.bh + f.txt * 1.7)) / 2) + f.bh + f.txt * 0.35
        renderType: Text.CurveRendering
        text: b.present ? Math.round(b.level * 100) + "%" : "—"
        color: f.mainC
        font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: f.txt
    }
}
