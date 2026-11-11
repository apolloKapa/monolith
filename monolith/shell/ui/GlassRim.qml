import QtQuick
import QtQuick.Effects
import "../core"

// Liquid glass's light on a pane (the Liquid glass style): a bright rim where light catches the
// edge (strongest along the top, a weaker bounce along the bottom) and a soft shine across the
// upper part. Fill the pane with it and give it the pane's corner radius. Draws nothing in
// other styles.
Item {
    id: gr
    property real radius: 0
    property real strength: 1
    visible: Theme.liquid && width > 4 && height > 4
    // the shine: from the top, fading out before the middle; a faint glow comes back at the bottom
    Rectangle {
        anchors.fill: parent
        radius: gr.radius
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.16 * gr.strength) }
            GradientStop { position: 0.38; color: Qt.rgba(1, 1, 1, 0.025 * gr.strength) }
            GradientStop { position: 0.8; color: "transparent" }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.06 * gr.strength) }
        }
    }
    // the rim: a light running round the edge, cut to a thin ring of the pane's shape
    Rectangle {
        id: rimLight
        anchors.fill: parent
        visible: false
        layer.enabled: gr.visible
        gradient: Gradient {
            GradientStop { position: 0.0; color: Qt.rgba(1, 1, 1, 0.75 * gr.strength) }
            GradientStop { position: 0.3; color: Qt.rgba(1, 1, 1, 0.22 * gr.strength) }
            GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0.08 * gr.strength) }
            GradientStop { position: 1.0; color: Qt.rgba(1, 1, 1, 0.32 * gr.strength) }
        }
    }
    Rectangle {
        id: ring
        anchors.fill: parent
        radius: gr.radius
        color: "transparent"
        border.width: 1.4
        border.color: "#ffffff"
        visible: false
        layer.enabled: gr.visible
    }
    MultiEffect {
        anchors.fill: parent
        source: rimLight
        maskEnabled: true
        maskSource: ring
        maskThresholdMin: 0.3
        maskSpreadAtMin: 0.6
    }
}
