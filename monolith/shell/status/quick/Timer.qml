import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// A timer (the same one as Tools and the island: +1 / +5 min while it runs) and a stopwatch with
// laps. Both keep going when the panel closes (core/Tasks).
ColumnLayout {
    id: tm
    spacing: 10
    property string mode: Tasks.swRunning || (Tasks.swMs > 0 && Tasks.total <= 0) ? "stopwatch" : "timer"

    RowLayout {
        Layout.fillWidth: true
        Label { text: tm.mode === "timer" ? "Timer" : "Stopwatch"; strong: true; font.pixelSize: Theme.sizeTitle; Layout.fillWidth: true }
        Segmented { width: 210; height: 34; opts: [["timer", "Timer"], ["stopwatch", "Stopwatch"]]; value: tm.mode; onPicked: v => tm.mode = v }
    }

    // ── timer ──
    ColumnLayout {
        visible: tm.mode === "timer"
        Layout.fillWidth: true
        spacing: 10
        Ring {
            Layout.alignment: Qt.AlignHCenter
            width: 200; height: 200
            thickness: 12
            value: Tasks.total > 0 ? Tasks.remaining / Tasks.total : 0
            text: Tasks.total > 0 ? Tasks.fmtLong(Tasks.remaining) : "—"
            caption: Tasks.total > 0 ? (Tasks.timing ? "running" : (Tasks.remaining > 0 ? "paused" : "done")) : "not set"
        }
        // running: more time, a little at a time
        RowLayout {
            visible: Tasks.total > 0 && Tasks.remaining > 0
            Layout.alignment: Qt.AlignHCenter
            spacing: 6
            Repeater {
                model: [1, 5, 10]
                Pressable {
                    required property int modelData
                    height: 32; width: al.implicitWidth + 22
                    color: Theme.containerHigh
                    onClicked: Tasks.addTime(modelData)
                    Label { id: al; anchors.centerIn: parent; text: "+" + parent.modelData + " min"; font.pixelSize: Theme.sizeSmall; strong: true }
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 6
            Repeater {
                model: [1, 3, 5, 10, 15, 20, 25, 30, 45, 60, 90]
                Pressable {
                    required property int modelData
                    height: 34; width: tl.implicitWidth + 24
                    color: Theme.control
                    onClicked: Tasks.startTimer(modelData)
                    Label { id: tl; anchors.centerIn: parent; text: parent.modelData >= 60 ? (parent.modelData / 60) + " h" : parent.modelData + " min"; font.pixelSize: Theme.sizeSmall }
                }
            }
        }
        NumberBox { id: mins; Layout.fillWidth: true; from: 1; to: 600; slideTo: 120; unit: "min"; value: 20; onMoved: v => value = v }
        RowLayout {
            Layout.fillWidth: true
            Button { Layout.fillWidth: true; text: "Start " + mins.value + " min"; primary: true; onClicked: Tasks.startTimer(mins.value) }
            Button { visible: Tasks.total > 0; text: Tasks.timing ? "Pause" : (Tasks.remaining > 0 ? "Resume" : "Clear"); onClicked: { if (Tasks.remaining <= 0) Tasks.total = 0; else Tasks.timing = !Tasks.timing; } }
            Button { visible: Tasks.total > 0 && Tasks.remaining > 0; text: "Stop"; onClicked: { Tasks.timing = false; Tasks.total = 0; Tasks.remaining = 0; } }
        }
    }

    // ── stopwatch ──
    ColumnLayout {
        visible: tm.mode === "stopwatch"
        Layout.fillWidth: true
        Layout.fillHeight: true
        spacing: 10
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 110
            radius: Theme.corner(110, 4)
            color: Theme.container
            Text {
                anchors.centerIn: parent
                text: Tasks.fmtMs(Tasks.swMs)
                color: Tasks.swRunning ? Theme.accent : Theme.text
                font.family: Theme.fontFamily; font.pixelSize: 46; font.weight: Font.Bold
                font.features: { "tnum": 1 }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Button { Layout.fillWidth: true; primary: true; icon: Tasks.swRunning ? "pause" : "play_arrow"; text: Tasks.swRunning ? "Pause" : (Tasks.swMs > 0 ? "Resume" : "Start"); onClicked: Tasks.swToggle() }
            Button { icon: "flag"; text: "Lap"; enabled: Tasks.swRunning; onClicked: Tasks.swLap() }
            Button { icon: "restart_alt"; text: "Reset"; enabled: Tasks.swMs > 0; onClicked: Tasks.swReset() }
        }
        // laps: the time at each, and how long that lap took
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            spacing: 2
            model: Tasks.laps
            delegate: Rectangle {
                required property var modelData
                required property int index
                width: ListView.view.width; height: 34
                radius: Theme.corner(34, -4)
                color: index % 2 === 0 ? Theme.container : "transparent"
                readonly property real split: modelData - (index + 1 < Tasks.laps.length ? Tasks.laps[index + 1] : 0)
                Label { x: 12; anchors.verticalCenter: parent.verticalCenter; text: "Lap " + (Tasks.laps.length - index); muted: true; font.pixelSize: Theme.sizeSmall }
                Label { anchors.horizontalCenter: parent.horizontalCenter; anchors.verticalCenter: parent.verticalCenter; text: "+" + Tasks.fmtMs(parent.split); font.pixelSize: Theme.sizeSmall }
                Label { anchors.right: parent.right; anchors.rightMargin: 12; anchors.verticalCenter: parent.verticalCenter; text: Tasks.fmtMs(parent.modelData); strong: true; font.pixelSize: Theme.sizeSmall }
            }
            Label { anchors.centerIn: parent; visible: Tasks.laps.length === 0; text: "Laps show up here"; muted: true; font.pixelSize: Theme.sizeSmall }
        }
    }
    Item { visible: tm.mode === "timer"; Layout.fillHeight: true }
}
