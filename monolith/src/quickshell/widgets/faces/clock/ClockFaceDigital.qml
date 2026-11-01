import QtQuick
import QtQuick.Effects
import "../../../reusables"
import "../../../"
import "ClockColors.js" as CC

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 120
    property real minHeight: 60
    property real maxWidth: 1400
    property real maxHeight: 700
    property real minAspect: 1.2
    property real maxAspect: 5.0
    property bool isRound: false

    // colours (see ClockColors.js): one for the whole clock, or one per digit
    property string clockColor: ""
    property bool perDigit: false
    property string digitColors: ""
    readonly property bool customColors: { let _ = [clockColor, perDigit, digitColors]; return CC.isCustom(root); }

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.06
        readonly property color baseColor: Qt.tint(ThemeBackend.text, Qt.alpha(ThemeBackend.mauve, 0.14))
        text: root.customColors ? CC.rich(DateTime.hour + DateTime.minute, root, ThemeBackend, baseColor, 0) : DateTime.hour + DateTime.minute
        textFormat: root.customColors ? Text.StyledText : Text.PlainText
        font.family: ThemeBackend.fontFamily
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 12
        font.weight: ThemeBackend.weightBlack
        font.letterSpacing: height * 0.01
        color: baseColor
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        layer.enabled: true
        layer.smooth: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: Scaler.s(3)
            shadowBlur: 0.55
            shadowOpacity: 0.5
        }
    }
}
