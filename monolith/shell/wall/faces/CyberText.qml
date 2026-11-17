import QtQuick
import "../../core"

// Cyberpunk text: the words with a pink and a cyan ghost a little to either side (a split signal),
// fitted into its box. `card`: the CyberCard it's on (for the colours and the type).
Item {
    id: ct
    property var card: null
    property string text: ""
    property color color: card ? card.ink : "white"
    property real split: Math.max(1, height * 0.03)
    property int align: Text.AlignLeft
    property int weight: Font.Bold
    property bool ghosts: true
    readonly property alias implicitTextWidth: main.contentWidth
    component Line: Text {
        renderType: Text.CurveRendering
        anchors.fill: parent
        text: ct.text
        font.family: ct.card ? ct.card.fam : Theme.fontFamily
        font.weight: ct.weight
        font.pixelSize: Math.max(8, ct.height)
        fontSizeMode: Text.Fit
        minimumPixelSize: 8
        horizontalAlignment: ct.align
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    Line { visible: ct.ghosts; color: Qt.alpha(ct.card ? ct.card.hot : "#ff2a6d", 0.55); anchors.leftMargin: -ct.split; anchors.rightMargin: ct.split }
    Line { visible: ct.ghosts; color: Qt.alpha(ct.card ? ct.card.edge : "#00f0ff", 0.55); anchors.leftMargin: ct.split; anchors.rightMargin: -ct.split }
    Line { id: main; color: ct.color }
}
