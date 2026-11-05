import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// The system's usage: CPU, memory, GPU and temperature, with the last two minutes.
ColumnLayout {
    spacing: 10
    Label { text: "System"; strong: true; font.pixelSize: Theme.sizeTitle }
    GridLayout {
        Layout.fillWidth: true
        columns: 2
        rowSpacing: 10; columnSpacing: 10
        Repeater {
            model: [[Stats.cpu, Math.round(Stats.cpu * 100) + "%", "CPU"], [Stats.mem, Math.round(Stats.mem * 100) + "%", "Memory"],
                    [Stats.gpu, Math.round(Stats.gpu * 100) + "%", "GPU"], [Math.min(1, Stats.temp / 100), Math.round(Stats.temp) + "°", "Temperature"]]
            Ring {
                required property var modelData
                Layout.alignment: Qt.AlignHCenter
                width: 120; height: 120
                thickness: 10
                value: modelData[0]; text: modelData[1]; caption: modelData[2]
            }
        }
    }
    Label { text: "CPU, last two minutes"; muted: true; font.pixelSize: Theme.sizeSmall }
    Spark { Layout.fillWidth: true; Layout.preferredHeight: 60; values: Stats.cpuHist }
    Item { Layout.fillHeight: true }
}
