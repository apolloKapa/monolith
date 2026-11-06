import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Lock screen: big bold hours (accent) and minutes, the date in spaced capitals under them.
// Narrow: the hours stack over the minutes.
FaceBase {
    id: f
    readonly property bool stacked: width / height < 1.25
    readonly property string date: Qt.formatDate(f.now, "dddd, d MMMM").toUpperCase()
    component Big: Inked { font.weight: Font.Bold; shadowY: 3; shadowStrength: 0.4 }
    ColumnLayout {
        visible: f.stacked
        anchors.centerIn: parent
        spacing: 8
        scale: Math.min(f.width / Math.max(1, implicitWidth), f.height / Math.max(1, implicitHeight))
        Big { Layout.alignment: Qt.AlignHCenter; Layout.bottomMargin: -28; text: Qt.formatTime(f.now, "HH"); color: Theme.accent; font.pixelSize: 150 }
        Big { Layout.alignment: Qt.AlignHCenter; text: Qt.formatTime(f.now, "mm"); font.pixelSize: 150 }
        Big { Layout.alignment: Qt.AlignHCenter; text: f.date; color: Theme.subtext; font.pixelSize: 16; font.weight: Font.Medium; font.letterSpacing: 1.4 }
    }
    ColumnLayout {
        visible: !f.stacked
        anchors.centerIn: parent
        spacing: 8
        scale: Math.min(f.width / Math.max(1, implicitWidth), f.height / Math.max(1, implicitHeight))
        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 4
            Big { text: Qt.formatTime(f.now, "HH"); color: Theme.accent; font.pixelSize: 120 }
            Big { text: ":"; color: Theme.subtext; font.pixelSize: 80; Layout.alignment: Qt.AlignVCenter }
            Big { text: Qt.formatTime(f.now, "mm"); font.pixelSize: 120 }
        }
        Big { Layout.alignment: Qt.AlignHCenter; text: f.date; color: Theme.subtext; font.pixelSize: 16; font.weight: Font.Medium; font.letterSpacing: 1.4 }
    }
}
