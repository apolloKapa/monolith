import QtQuick
import "../../../reusables"
import "../../../"
import "ClockColors.js" as CC

// Hours above minutes, big and tight: the hours in full text colour, the minutes in the softer text colour (both fully opaque).
Item {
    id: root
    anchors.fill: parent

    property real minWidth: 80
    property real minHeight: 120
    property real maxWidth: 800
    property real maxHeight: 1000
    property real minAspect: 0.3
    property real maxAspect: 1.4
    property bool isRound: false

    // colours (see ClockColors.js): one for the whole clock, or one per digit
    property string clockColor: ""
    property bool perDigit: false
    property string digitColors: ""
    property bool clockGradient: false
    property string clockColor2: ""
    property string gradientDirection: "horizontal"
    readonly property bool gradientOn: clockGradient && !perDigit
    readonly property bool customColors: { let _ = [clockColor, perDigit, digitColors, gradientOn]; return CC.isCustom(root); }

    // the gradient: everything is drawn white (see ClockColors.js) and this colours it
    layer.enabled: gradientOn
    layer.smooth: true
    layer.effect: ShaderEffect {
        property color colorA: CC.resolve(root.clockColor, ThemeBackend, ThemeBackend.text)
        property color colorB: CC.resolve(root.clockColor2, ThemeBackend, ThemeBackend.mauve)
        property real direction: root.gradientDirection === "vertical" ? 1.0 : 0.0
        fragmentShader: "file://" + Caching.monolithDir + "/assets/shaders/ui/gradient_tint.frag.qsb"
    }

    readonly property real lineH: height / 2

    Column {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: -root.lineH * 0.26

        Text {
            text: root.customColors ? CC.rich(DateTime.hour, root, ThemeBackend, ThemeBackend.text, 0) : DateTime.hour
            textFormat: root.customColors ? Text.StyledText : Text.PlainText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.lineH * 1.05
            font.weight: Font.DemiBold
            color: ThemeBackend.text
        }
        Text {
            text: root.customColors ? CC.rich(DateTime.minute, root, ThemeBackend, ThemeBackend.subtext0, 2) : DateTime.minute
            textFormat: root.customColors ? Text.StyledText : Text.PlainText
            font.family: ThemeBackend.fontFamily
            font.pixelSize: root.lineH * 1.05
            font.weight: Font.DemiBold
            color: ThemeBackend.subtext0
        }
    }
}
