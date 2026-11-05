import QtQuick
import "../core"

Text {
    property bool muted: false
    property bool strong: false
    font.family: Theme.fontFamily
    font.pixelSize: Theme.sizeBody
    font.weight: strong ? Font.DemiBold : Font.Normal
    color: muted ? Theme.subtext : Theme.text
    elide: Text.ElideRight
    renderType: Text.NativeRendering
}
