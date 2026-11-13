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
    // a see-through card (Panel opacity): the shadow is drawn only outside the card. Drawn
    // under it too, it laid a dark layer behind the card that hid half of the blur
    readonly property bool hollow: cs.color.a < 0.99
    readonly property real spread: Math.ceil(Theme.shadowPx + Math.max(Math.abs(Theme.shadowX), Math.abs(cs.offsetY)) + 4)
    // the shadow, on a box reaching `spread` past the card on every side (so a layer of it holds
    // the whole shadow: a layer only as big as the card squeezed the shadow inside the card)
    Item {
        id: shadowBox
        x: -cs.spread; y: -cs.spread
        width: cs.width + 2 * cs.spread; height: cs.height + 2 * cs.spread
        visible: shadowLoader.active
        layer.enabled: cs.hollow && shadowLoader.active
        layer.effect: MultiEffect {
            maskEnabled: true
            maskInverted: true
            maskSource: hole
            maskThresholdMin: 0.5
            maskSpreadAtMin: 0.2
        }
        Loader {
            id: shadowLoader
            x: cs.spread; y: cs.spread
            width: cs.width; height: cs.height
            active: Theme.rectShadows && Theme.shadowOn
            source: "RectShadow.qml"
            onLoaded: {
                item.anchors.fill = shadowLoader;
                item.radius = Qt.binding(() => cs.radius);
                item.blur = Qt.binding(() => Theme.shadowPx);
                item.offset = Qt.binding(() => Qt.vector2d(Theme.shadowX, cs.offsetY));
                item.color = Qt.binding(() => Theme.shadowColor);
            }
        }
    }
    // the card's shape, where it sits in the shadow's box (the mask: no shadow there)
    Item {
        id: hole
        visible: false
        width: shadowBox.width; height: shadowBox.height
        layer.enabled: cs.hollow
        Rectangle { x: cs.spread; y: cs.spread; width: cs.width; height: cs.height; radius: cs.radius }
    }
    // on a Qt without RectangularShadow: a copy of the card's shape casts the shadow, the old way
    // (blurred off-screen). Only then: drawn always, it was a second layer of the card's colour
    // under the card, so a see-through panel (Panel opacity) came out far more solid than set
    // (75 % read as about 94 %) and the blur behind it hardly showed
    Rectangle {
        visible: !Theme.rectShadows
        anchors.fill: parent; radius: cs.radius; color: cs.color
        layer.enabled: !Theme.rectShadows
        layer.effect: MultiEffect { shadowEnabled: true; shadowBlur: Theme.shadowBlur; shadowColor: Theme.shadowColor; shadowVerticalOffset: cs.offsetY; shadowHorizontalOffset: Theme.shadowX }
    }
}
