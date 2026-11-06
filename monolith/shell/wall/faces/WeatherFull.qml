import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Weather, full: glass; the big icon and temperature on the left, the city and the conditions on
// the right with the next hours under them.
FaceBase {
    id: f
    WeatherTone { id: wt }
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Fit {
        dw: 400; dh: 170
        RowLayout {
            anchors.fill: parent
            anchors.margins: 18
            spacing: 18
            ColumnLayout {
                spacing: 0
                Icon { name: wt.icon; filled: true; size: 56; color: wt.color }
                Text { text: wt.temp; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: 46 }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                Text { Layout.fillWidth: true; text: Weather.city || "Weather"; elide: Text.ElideRight; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: 18 }
                Text { Layout.fillWidth: true; text: wt.words; elide: Text.ElideRight; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: 13 }
                Item { Layout.fillHeight: true }
                RowLayout {
                    Layout.fillWidth: true
                    Repeater {
                        model: Weather.hours.filter((h, i) => i % 2 === 0).slice(1, 6)
                        ColumnLayout {
                            required property var modelData
                            Layout.fillWidth: true
                            spacing: 2
                            Text { Layout.alignment: Qt.AlignHCenter; text: Math.round(modelData.temp) + "°"; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: 12 }
                            Icon { Layout.alignment: Qt.AlignHCenter; name: Weather.icon(modelData.code, true); filled: true; size: 20; color: wt.tone(modelData.code) }
                            Text { Layout.alignment: Qt.AlignHCenter; text: modelData.time; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: 11 }
                        }
                    }
                }
            }
        }
    }
}
