import QtQuick
import QtQuick.Effects
import "../core"

// A card's drop shadow, drawn under it: put it inside the card. The shadow is a
// RectangularShadow, drawn straight by a shader: the card isn't rendered off-screen and blurred
// any more. That blur had to be redone on every frame while a card changed size (a menu
// growing out of the bar), which made menus stutter and come up late on older laptops.
Item {
    id: cs
    anchors.fill: parent
    z: -1
    // Liquid glass: the card is a pane of glass (under the card's own faint fill and content)
    LiquidPane { parent: cs.parent; anchors.fill: parent; radius: cs.radius; z: -0.5; visible: Theme.liquid && cs.visible }
    // how far the shadow falls down (the bar's pills keep it centred: they float on the screen)
    property real offsetY: Theme.shadowY
    property real radius: parent && parent.radius !== undefined ? parent.radius : 0
    // (liquid glass: the card's fill is nearly clear, so the shadow is cast by a solid copy)
    property color color: Theme.liquid ? Qt.alpha(Theme.frame, 1) : (parent && parent.color !== undefined ? parent.color : Theme.frame)
    // (loaded by URL: an older Qt doesn't have it, see RectShadow.qml)
    Loader {
        anchors.fill: parent
        active: Theme.rectShadows && Theme.shadowOn
        source: "RectShadow.qml"
        onLoaded: {
            item.radius = Qt.binding(() => cs.radius);
            item.blur = Qt.binding(() => Theme.shadowPx);
            item.offset = Qt.binding(() => Qt.vector2d(Theme.shadowX, cs.offsetY));
            item.color = Qt.binding(() => Theme.shadowColor);
        }
    }
    // the card's fill under the card, as the shadow's source used to draw it; on a Qt without
    // RectangularShadow it casts the shadow itself, the old way (blurred off-screen)
    Rectangle {
        anchors.fill: parent; radius: cs.radius; color: cs.color
        layer.enabled: !Theme.rectShadows
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: cs.offsetY; shadowHorizontalOffset: Theme.shadowX }
    }
}
