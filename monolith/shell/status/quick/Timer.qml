import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// A timer (the same one as Tools and the island).
ColumnLayout {
    spacing: 10
    Label { text: "Timer"; strong: true; font.pixelSize: Theme.sizeTitle }
    Ring {
        Layout.alignment: Qt.AlignHCenter
        width: 190; height: 190
        thickness: 12
        value: Tasks.total > 0 ? Tasks.remaining / Tasks.total : 0
        text: Tasks.total > 0 ? Tasks.fmt(Tasks.remaining) : "—"
        caption: Tasks.total > 0 ? (Tasks.timing ? "running" : (Tasks.remaining > 0 ? "paused" : "done")) : "not set"
    }
    Flow {
        Layout.fillWidth: true
        spacing: 6
        Repeater {
            model: [1, 5, 10, 15, 25, 45, 60]
            Pressable {
                required property int modelData
                height: 34; width: tl.implicitWidth + 24
                color: Theme.control
                onClicked: Tasks.startTimer(modelData)
                Label { id: tl; anchors.centerIn: parent; text: parent.modelData + " min"; font.pixelSize: Theme.sizeSmall }
            }
        }
    }
    NumberBox { id: mins; Layout.fillWidth: true; from: 1; to: 600; slideTo: 120; unit: "min"; value: 20; onMoved: v => value = v }
    RowLayout {
        Layout.fillWidth: true
        Button { Layout.fillWidth: true; text: "Start " + mins.value + " min"; primary: true; onClicked: Tasks.startTimer(mins.value) }
        Button { visible: Tasks.total > 0; text: Tasks.timing ? "Pause" : (Tasks.remaining > 0 ? "Resume" : "Clear"); onClicked: { if (Tasks.remaining <= 0) Tasks.total = 0; else Tasks.timing = !Tasks.timing; } }
    }
    Item { Layout.fillHeight: true }
}
