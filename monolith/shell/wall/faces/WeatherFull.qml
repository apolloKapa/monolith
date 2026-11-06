import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Weather, full: glass; the condition's icon top-left and the temperature (with what it feels
// like) bottom-left; the city and conditions top-right and the next hours bottom-right. Sizes
// follow the widget: everything grows with it, and a wider one shows a fourth hour.
FaceBase {
    id: f
    WeatherTone { id: wt }
    readonly property real ref: Math.min(height, width * 0.6)
    readonly property real m: Math.max(12, ref * 0.09)
    readonly property real gap: Math.max(8, ref * 0.05)
    readonly property real inner: Math.max(0, height - 2 * m)
    readonly property int count: width >= 360 ? 4 : 3
    // the hours from now on
    readonly property var next: {
        const h = new Date().getHours(), l = Weather.hours;
        let i = l.findIndex(x => parseInt(x.time) >= h);
        return l.slice(Math.max(0, i), Math.max(0, i) + count);
    }
    Glass { anchors.fill: parent; ctx: f.ctx; radius: Theme.corner(80, 16) }
    Text {
        anchors.centerIn: parent
        visible: !wt.ready
        text: "Getting the weather…"
        color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Math.max(11, f.inner * 0.09)
    }
    RowLayout {
        visible: wt.ready
        anchors.fill: parent
        anchors.margins: f.m
        spacing: f.gap
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1
            spacing: 0
            Icon { Layout.alignment: Qt.AlignTop | Qt.AlignLeft; name: wt.icon; filled: true; size: Math.max(28, Math.min(78, f.inner * 0.36)); color: wt.color }
            Item { Layout.fillHeight: true }
            Text { text: wt.temp; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Black; font.pixelSize: Math.max(24, Math.min(64, f.inner * 0.3)) }
            Text {
                text: wt.ready && Weather.current.feels !== undefined ? "Feels like " + Math.round(Weather.current.feels) + "°" : ""
                color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: Math.max(10, Math.min(14, f.inner * 0.085))
            }
        }
        ColumnLayout {
            Layout.fillWidth: true; Layout.fillHeight: true; Layout.preferredWidth: 1.3
            spacing: 2
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: Weather.city || "Weather"; color: Theme.text; font.family: Theme.fontFamily; font.weight: Font.Bold; font.pixelSize: Math.max(13, Math.min(20, f.inner * 0.105)) }
            Text { Layout.fillWidth: true; horizontalAlignment: Text.AlignRight; elide: Text.ElideRight; text: wt.words; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: Math.max(11, Math.min(16, f.inner * 0.085)) }
            Item { Layout.fillHeight: true }
            RowLayout {
                Layout.alignment: Qt.AlignBottom | Qt.AlignRight
                spacing: Math.max(6, f.gap * 0.9)
                Repeater {
                    model: f.next
                    ColumnLayout {
                        required property var modelData
                        spacing: 4
                        Text { Layout.alignment: Qt.AlignHCenter; text: Math.round(modelData.temp) + "°"; color: Theme.subtext; font.family: Theme.fontFamily; font.weight: Font.Medium; font.pixelSize: Math.max(11, Math.min(18, f.inner * 0.085)) }
                        Icon { Layout.alignment: Qt.AlignHCenter; name: Weather.icon(modelData.code, parseInt(modelData.time) >= 6 && parseInt(modelData.time) < 20); filled: true; size: Math.max(20, Math.min(32, f.inner * 0.15)); color: wt.tone(modelData.code) }
                        Text { Layout.alignment: Qt.AlignHCenter; text: modelData.time; color: Theme.subtext; font.family: Theme.fontFamily; font.pixelSize: Math.max(9, Math.min(13, f.inner * 0.065)) }
                    }
                }
            }
        }
    }
}
