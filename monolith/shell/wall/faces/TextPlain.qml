import QtQuick
import "../../core"
import "../../ui"

// Text: whatever you typed in the editor, bold and as large as fits (wrapping onto more lines
// when that's larger); a faint "Your text" until there's something.
FaceBase {
    id: face
    clip: true
    readonly property string words: String(face.opt("textContent", "")).trim()
    FillText {
        minimumPixelSize: 8
        font.weight: Font.Bold
        wrapMode: Text.Wrap
        text: face.words !== "" ? face.opt("textContent", "") : "Your text"
        opacity: face.words !== "" ? 1 : 0.4
        shadowY: 1.5
    }
}
