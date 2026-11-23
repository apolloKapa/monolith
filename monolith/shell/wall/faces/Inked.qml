import QtQuick
import QtQuick.Effects
import "../../core"
import "../../ui"

// Text straight on the wallpaper: bold, with a soft drop shadow so it reads on any picture.
//
// The text itself is drawn directly, as curves (CurveRendering), so it's sharp at any size: a
// look is laid out at its design size and scaled to the widget, and a clock dragged large (or
// small) keeps crisp digits. Only its shadow is a picture: a black copy behind it, blurred.
// (The text and its shadow used to be one picture, made at the design size and stretched or
// squeezed to the widget: every clock that wasn't exactly its design size was soft, and a big
// one plainly blurry.)
Text {
    id: ink
    renderType: Text.CurveRendering
    property real shadowY: 2
    property real shadowStrength: 0.55
    font.family: Theme.fontFamily
    color: Theme.text
    Text {
        // (behind the text it belongs to)
        z: -1
        y: ink.shadowY
        width: ink.width
        height: ink.height
        visible: ink.shadowStrength > 0 && ink.text !== ""
        // (digits coloured one by one are rich text, each in a <font color>: the shadow is the
        // same letters without that, or it would be coloured too)
        text: ink.textFormat === Text.PlainText ? ink.text
            : ink.text.replace(/<[^>]*>/g, "").replace(/&lt;/g, "<").replace(/&gt;/g, ">").replace(/&amp;/g, "&")
        textFormat: Text.PlainText
        renderType: Text.CurveRendering
        font: ink.font
        fontSizeMode: ink.fontSizeMode
        minimumPixelSize: ink.minimumPixelSize
        horizontalAlignment: ink.horizontalAlignment
        verticalAlignment: ink.verticalAlignment
        wrapMode: ink.wrapMode
        elide: ink.elide
        maximumLineCount: ink.maximumLineCount
        lineHeight: ink.lineHeight
        lineHeightMode: ink.lineHeightMode
        color: "#000000"
        opacity: ink.shadowStrength
        layer.enabled: true
        layer.effect: MultiEffect {
            blurEnabled: true
            blur: 0.4
            blurMax: 32
            autoPaddingEnabled: true
        }
    }
}
