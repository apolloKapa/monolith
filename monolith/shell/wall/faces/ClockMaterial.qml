import QtQuick
import "../../core"
import "../../ui"

// Material: hours over minutes as a 2 × 2 block of digits, set in the font's heaviest, roundest
// cut. The digits alternate between the main colour and the accent like a chequerboard, and each
// sits on two soft shadows (a near one and a farther, fainter one).
FaceBase {
    id: face
    clip: true
    layer.enabled: face.gradientOn
    layer.effect: GradientTint { from: face.gradFrom; to: face.gradTo; dir: face.gradVec }
    readonly property string family: face.fontOr("Google Sans Flex")
    readonly property var axes: ({ "wght": 1000, "ROND": 100, "wdth": 100 })
    readonly property string digits: Qt.formatTime(face.now, "HHmm")

    // Every digit gets the same cell: the largest ink box of 0–9, measured once at 100 px.
    FontMetrics { id: probe; font.family: face.family; font.pixelSize: 100; font.weight: Font.Black; font.variableAxes: face.axes }
    readonly property var glyphBox: Array.from({ length: 10 }, (_, n) => probe.tightBoundingRect(String(n)))
    readonly property size unit: Qt.size(Math.max(1, ...glyphBox.map(b => b.width)), Math.max(1, ...glyphBox.map(b => b.height)))
    // the size the digits are set at so the block takes 94 % of the widget either way
    readonly property real fontPx: 100 * Math.min(width * 0.94 / (2 * unit.width), height * 0.94 / (2 * unit.height))
    readonly property real cellW: unit.width * fontPx / 100
    readonly property real cellH: unit.height * fontPx / 100

    // one digit drawn once: dropped by `drop` (of the font size), in `tone`
    component Glyph: Text {
        property real drop: 0
        property color tone
        renderType: Text.CurveRendering
        font.family: face.family
        font.pixelSize: face.fontPx
        font.weight: Font.Black
        font.variableAxes: face.axes
        color: tone
    }

    Item {
        width: face.cellW * 2
        height: face.cellH * 2
        anchors.centerIn: parent
        Repeater {
            model: 4
            Item {
                id: cell
                required property int index
                readonly property string digit: face.digits.charAt(index)
                readonly property rect box: face.glyphBox[Number(digit) || 0]
                // centred in its cell by its own ink, not its advance
                readonly property real inkX: (face.cellW - box.width * face.fontPx / 100) / 2 - box.x * face.fontPx / 100
                readonly property color own: (index === 0 || index === 3) ? face.mainC : face.accentC
                x: (index % 2) * face.cellW
                y: (index > 1 ? 1 : 0) * face.cellH
                width: face.cellW
                height: face.cellH
                // shadows first (far, then near), the digit on top
                Repeater {
                    model: [{ drop: 0.045, a: 0.14 }, { drop: 0.022, a: 0.26 }]
                    Glyph {
                        required property var modelData
                        x: cell.inkX
                        y: cell.height - baselineOffset + face.fontPx * modelData.drop
                        text: cell.digit
                        tone: Qt.rgba(0, 0, 0, modelData.a)
                    }
                }
                Glyph {
                    x: cell.inkX
                    y: cell.height - baselineOffset
                    text: cell.digit
                    tone: face.inkColor(face.digitsOn ? face.digitColor(cell.index, cell.own) : cell.own)
                }
            }
        }
    }
}
