import QtQuick
import "../../core"
import "../../ui"

// Material: the four digits in a tight 2×2 grid, rounded and as heavy as they get, coloured
// like a checkerboard (on-surface and primary) with a soft double shadow under each.
FaceBase {
    id: f
    clip: true
    readonly property string hh: Qt.formatTime(f.now, "HH")
    readonly property string mm: Qt.formatTime(f.now, "mm")
    readonly property string fam: "Google Sans Flex"
    // the widest and tallest ink of any digit at 100 px, so every digit gets the same cell
    FontMetrics { id: ref; font.family: f.fam; font.pixelSize: 100; font.weight: Font.Black }
    readonly property var ink: { const r = []; for (let i = 0; i < 10; i++) r.push(ref.tightBoundingRect(String(i))); return r; }
    readonly property real refW: Math.max(1, ...ink.map(r => r.width))
    readonly property real refH: Math.max(1, ...ink.map(r => r.height))
    readonly property real px: Math.min(width * 0.94 / (2 * refW), height * 0.94 / (2 * refH)) * 100
    readonly property real cw: refW * px / 100
    readonly property real chh: refH * px / 100
    Item {
        anchors.centerIn: parent
        width: f.cw * 2; height: f.chh * 2
        Repeater {
            model: 4
            Item {
                id: cell
                required property int index
                readonly property int col: index % 2
                readonly property int row: Math.floor(index / 2)
                readonly property string digit: (row === 0 ? f.hh : f.mm).charAt(col)
                readonly property var r: f.ink[Number(digit) || 0]
                readonly property real tx: (f.cw - r.width * f.px / 100) / 2 - r.x * f.px / 100
                x: col * f.cw; y: row * f.chh
                width: f.cw; height: f.chh
                Repeater {
                    model: [[0.045, 0.14], [0.022, 0.26], [0, -1]]
                    Text {
                        required property var modelData
                        x: cell.tx
                        y: cell.height - baselineOffset + f.px * modelData[0]
                        text: cell.digit
                        font.family: f.fam; font.pixelSize: f.px; font.weight: Font.Black
                        color: modelData[1] < 0 ? ((cell.row + cell.col) % 2 === 0 ? Theme.text : Theme.accent) : Qt.rgba(0, 0, 0, modelData[1])
                    }
                }
            }
        }
    }
}
