import QtQuick
import "../../core"
import "../../ui"

// The bar's five styles as cards, each a little picture of it; a click sets it (Settings → Bar,
// the welcome).
Flow {
    spacing: 8
    Repeater {
        model: [["island", "Island", "One pill hanging from the top"], ["fill", "Fill", "A bar along the top edge"],
                ["frame", "Frame", "The bar and a border round the screen"], ["solid", "Solid", "One floating bar"],
                ["modular", "Modular", "Each section on its own pill"]]
        Pressable {
            id: sc
            required property var modelData
            readonly property bool on: Theme.barStyle === modelData[0]
            readonly property string st: modelData[0]
            width: 150; height: 132
            color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.container)
            border.width: on ? 2 : 0; border.color: Theme.accent
            onClicked: Store.set("bar.style", modelData[0])
            // a little screen
            Rectangle {
                id: mini
                x: 10; y: 10; width: parent.width - 20; height: 66
                radius: 6; clip: true
                gradient: Gradient {
                    GradientStop { position: 0; color: Qt.tint(Theme.control, Qt.alpha(Theme.accent, 0.3)) }
                    GradientStop { position: 1; color: Theme.m("surface_container_lowest", "#101014") }
                }
                readonly property color bc: sc.on ? Theme.accent : Theme.text
                // frame: the border
                Rectangle { visible: sc.st === "frame"; anchors.fill: parent; color: "transparent"; border.width: 4; border.color: Qt.alpha(mini.bc, 0.7); radius: 6 }
                // island: a pill hanging from the top
                Rectangle { visible: sc.st === "island"; anchors.horizontalCenter: parent.horizontalCenter; y: -6; width: 62; height: 16; radius: 8; color: Qt.alpha(mini.bc, 0.7) }
                // fill / frame: a bar along the top
                Rectangle { visible: sc.st === "fill" || sc.st === "frame"; width: parent.width; height: 10; color: Qt.alpha(mini.bc, 0.7) }
                // solid: one floating bar
                Rectangle { visible: sc.st === "solid"; x: 5; y: 5; width: parent.width - 10; height: 10; radius: 5; color: Qt.alpha(mini.bc, 0.7) }
                // modular: three floating pills
                Repeater {
                    model: sc.st === "modular" ? [[5, 30], [mini.width / 2 - 14, 28], [mini.width - 39, 34]] : []
                    Rectangle { required property var modelData; x: modelData[0]; y: 5; width: modelData[1]; height: 10; radius: 5; color: Qt.alpha(mini.bc, 0.7) }
                }
                // a window
                Rectangle { x: sc.st === "frame" ? 8 : 6; y: 22; width: parent.width - (sc.st === "frame" ? 16 : 12); height: parent.height - y - (sc.st === "frame" ? 8 : 5); radius: 3; color: Qt.alpha(Theme.text, 0.1) }
            }
            Column {
                x: 10; y: mini.y + mini.height + 6; width: parent.width - 20
                Label { text: sc.modelData[1]; strong: true; font.pixelSize: Theme.sizeSmall + 1; color: sc.on ? Theme.onAccentContainer : Theme.text }
                Label { width: parent.width; text: sc.modelData[2]; muted: true; font.pixelSize: Theme.sizeSmall - 2; elide: Text.ElideRight }
            }
        }
    }
}
