import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Weather, full: on glass. On the left the condition's icon at the top and the temperature with
// "feels like" at the bottom; on the right the city and the conditions at the top and the next few
// hours (temperature, icon, time) at the bottom. Everything scales with the widget; from 360 px
// wide it shows four hours instead of three.
FaceBase {
    id: face
    WeatherTone { id: sky }
    // the size things are measured against: the height, unless the widget is unusually narrow
    readonly property real basis: Math.min(height, width * 0.6)
    readonly property real pad: Math.max(12, basis * 0.09)
    readonly property real gutter: Math.max(8, basis * 0.05)
    readonly property real room: Math.max(0, height - 2 * pad)
    // a size between `lo` and `hi`, `part` of the room
    function sized(part, lo, hi) { return Math.max(lo, Math.min(hi, room * part)); }
    // the hours still to come today, from this one
    readonly property var upcoming: {
        const now = face.now.getHours(), all = Weather.hours;
        const from = Math.max(0, all.findIndex(h => parseInt(h.time) >= now));
        return all.slice(from, from + (width >= 360 ? 4 : 3));
    }
    component Line: Text { renderType: Text.CurveRendering; font.family: Theme.fontFamily; color: Theme.subtext }
    Glass { anchors.fill: parent; ctx: face.ctx; radius: Theme.corner(80, 16) }
    Line {
        visible: !sky.ready
        anchors.centerIn: parent
        text: Weather.noPlace ? "No location: set your city in Settings → General" : "Getting the weather…"
        font.pixelSize: Math.max(11, face.room * 0.09)
    }
    RowLayout {
        visible: sky.ready
        anchors.fill: parent
        anchors.margins: face.pad
        spacing: face.gutter
        // now
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1
            spacing: 0
            Icon { Layout.alignment: Qt.AlignTop | Qt.AlignLeft; name: sky.icon; filled: true; color: sky.color; size: face.sized(0.36, 28, 78) }
            Item { Layout.fillHeight: true }
            Line { text: sky.temp; color: Theme.text; font.weight: Font.Black; font.pixelSize: face.sized(0.3, 24, 64) }
            Line {
                text: sky.ready && Weather.current.feels !== undefined ? "Feels like " + Math.round(Weather.current.feels) + "°" : ""
                font.weight: Font.Medium
                font.pixelSize: face.sized(0.085, 10, 14)
            }
        }
        // where, what, and what's coming
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 1.3
            spacing: 2
            Line { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: Weather.city || "Weather"; color: Theme.text; font.weight: Font.Bold; font.pixelSize: face.sized(0.105, 13, 20) }
            Line { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: sky.words; font.weight: Font.Medium; font.pixelSize: face.sized(0.085, 11, 16) }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                spacing: Math.max(6, face.gutter * 0.9)
                Repeater {
                    model: face.upcoming
                    ColumnLayout {
                        id: hour
                        required property var modelData
                        readonly property int at: parseInt(modelData.time)
                        spacing: 4
                        Line { Layout.alignment: Qt.AlignHCenter; text: Math.round(hour.modelData.temp) + "°"; font.weight: Font.Medium; font.pixelSize: face.sized(0.085, 11, 18) }
                        Icon { Layout.alignment: Qt.AlignHCenter; name: Weather.icon(hour.modelData.code, hour.at >= 6 && hour.at < 20); filled: true; color: sky.tone(hour.modelData.code); size: face.sized(0.15, 20, 32) }
                        Line { Layout.alignment: Qt.AlignHCenter; text: hour.modelData.time; font.pixelSize: face.sized(0.065, 9, 13) }
                    }
                }
            }
        }
    }
}
