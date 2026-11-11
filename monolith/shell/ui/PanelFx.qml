import QtQuick
import QtQuick.Effects
import "../core"

// Theme → Effects on a panel (the open island, floating menus, the dock): film grain over it and a
// light along its top edge. Fill the panel with it, and give it the panel's corner radius.
Item {
    id: fx
    property real radius: 0
    visible: Theme.fxGrain || Theme.fxEdge || Theme.liquid
    // Liquid glass: the light rim and shine
    GlassRim { anchors.fill: parent; radius: fx.radius }
    // grain: a still noise tile, faint, kept inside the rounded shape
    Item {
        id: grainSrc
        anchors.fill: parent
        visible: false
        layer.enabled: Theme.fxGrain
        Image { anchors.fill: parent; source: "grain.png"; fillMode: Image.Tile; smooth: false }
    }
    MultiEffect {
        anchors.fill: parent
        visible: Theme.fxGrain
        source: grainSrc
        opacity: Theme.dark ? 0.07 : 0.09
        maskEnabled: true
        maskSource: grainMask
    }
    Rectangle { id: grainMask; anchors.fill: parent; radius: fx.radius; visible: false; layer.enabled: Theme.fxGrain }
    // edge: a thin light along the top, brightest in the middle
    Rectangle {
        visible: Theme.fxEdge
        x: fx.radius * 0.6; y: 0.5
        width: parent.width - 2 * x; height: 1
        gradient: Gradient {
            orientation: Gradient.Horizontal
            GradientStop { position: 0; color: "transparent" }
            GradientStop { position: 0.5; color: Qt.alpha(Theme.accent, 0.85) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
    Rectangle {
        visible: Theme.fxEdge
        x: fx.radius; y: 1
        width: parent.width - 2 * x; height: Math.min(28, parent.height / 3)
        gradient: Gradient {
            GradientStop { position: 0; color: Qt.alpha(Theme.accent, 0.10) }
            GradientStop { position: 1; color: "transparent" }
        }
    }
}
