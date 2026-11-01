import QtQuick
import QtQuick.Effects
import "../../../reusables"
import "../../../"
import "ClockColors.js" as CC

Item {
    id: root
    anchors.fill: parent
    clip: true

    property real minWidth: 80
    property real minHeight: 40
    property real maxWidth: 1200
    property real maxHeight: 600
    property real minAspect: 1.2
    property real maxAspect: 5.0
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

    Text {
        anchors.fill: parent
        anchors.margins: Math.min(parent.width, parent.height) * 0.05
        text: root.customColors ? CC.rich(DateTime.time, root, ThemeBackend, ThemeBackend.text, 0) : DateTime.time
        textFormat: root.customColors ? Text.StyledText : Text.PlainText
        font.family: ThemeBackend.fontFamily
        font.pixelSize: height
        fontSizeMode: Text.Fit
        minimumPixelSize: 10
        font.weight: ThemeBackend.weightBlack
        color: ThemeBackend.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter

        layer.enabled: true
        layer.effect: MultiEffect {
            shadowEnabled: true
            shadowColor: "#000000"
            shadowVerticalOffset: Scaler.s(1.5)
            shadowHorizontalOffset: 0
            shadowBlur: 0.35
            shadowOpacity: 0.55
        }
    }
}
