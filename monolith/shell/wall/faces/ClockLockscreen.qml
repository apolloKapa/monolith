import QtQuick
import QtQuick.Layouts
import "../../core"
import "../../ui"

// Lock screen: the hours in the accent and the minutes in the text colour, big and bold, a colon
// between them, and today's date in spaced capitals underneath. When the widget is narrow the
// hours sit on top of the minutes instead (and the colon goes). The whole block is scaled to fit.
FaceBase {
    id: face
    readonly property bool tall: width < height * 1.25
    readonly property real digitPx: tall ? 150 : 120
    layer.enabled: face.gradientOn
    layer.effect: GradientTint { from: face.gradFrom; to: face.gradTo; dir: face.gradVec }
    component Part: Inked { font.family: face.fontOr(Theme.fontFamily); font.weight: Font.Bold; shadowY: 3; shadowStrength: 0.4 }
    ColumnLayout {
        id: block
        anchors.centerIn: parent
        spacing: 8
        scale: Math.min(face.width / Math.max(1, implicitWidth), face.height / Math.max(1, implicitHeight))
        GridLayout {
            Layout.alignment: Qt.AlignHCenter
            columns: face.tall ? 1 : 3
            columnSpacing: 4
            rowSpacing: 8
            Part {
                Layout.alignment: Qt.AlignHCenter
                Layout.bottomMargin: face.tall ? -28 : 0
                font.pixelSize: face.digitPx
                textFormat: face.textFormatFor
                text: face.inked(Qt.formatTime(face.now, "HH"), face.accentC, 0)
                color: face.inkColor(face.accentC)
            }
            Part {
                visible: !face.tall
                Layout.alignment: Qt.AlignVCenter
                font.pixelSize: 80
                text: ":"
                color: face.inkColor(face.subC)
            }
            Part {
                Layout.alignment: Qt.AlignHCenter
                font.pixelSize: face.digitPx
                textFormat: face.textFormatFor
                text: face.inked(Qt.formatTime(face.now, "mm"), Theme.text, 2)
                color: face.inkColor(Theme.text)
            }
        }
        Part {
            Layout.alignment: Qt.AlignHCenter
            font.pixelSize: 16
            font.weight: Font.Medium
            font.letterSpacing: 1.4
            text: Qt.formatDate(face.now, "dddd, d MMMM").toUpperCase()
            color: face.subC
        }
    }
}
