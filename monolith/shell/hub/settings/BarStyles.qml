import QtQuick
import Quickshell
import Quickshell.Widgets
import "../../core"
import "../../ui"

// The bar's five styles as cards, each a little picture of your screen (your wallpaper, a
// window) with that style's bar on it in your theme's colours: a clock and a pill on the left,
// one in the middle, icons on the right. A click sets it (Settings → Bar, the welcome).
Flow {
    id: fl
    spacing: 10
    readonly property string wall: { const s = Quickshell.screens.find(x => x.name === Niri.focusedOutput) || Quickshell.screens[0]; const p = s ? Wall.pathFor(s.name) : ""; return Wall.isVideo(p) ? Wall.thumb(p) : p; }

    // what sits on a bar: a dot and a pill on the left, a pill in the middle, three dots on the
    // right (each part can be drawn on its own, for the modular style)
    component Bits: Item {
        id: bits
        property string part: "all"            // all | left | middle | right
        property color ink: Theme.text
        readonly property real u: height
        Row {
            visible: bits.part === "all" || bits.part === "left"
            x: bits.part === "all" ? bits.u * 0.5 : (bits.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: bits.u * 0.25
            Rectangle { width: bits.u * 0.55; height: width; radius: width / 2; color: Theme.accent }
            Rectangle { width: bits.u * 1.6; height: bits.u * 0.32; radius: height / 2; color: Qt.alpha(bits.ink, 0.75); anchors.verticalCenter: parent.verticalCenter }
        }
        Rectangle {
            visible: bits.part === "all" || bits.part === "middle"
            anchors.centerIn: parent
            width: bits.u * 1.8; height: bits.u * 0.32; radius: height / 2
            color: Qt.alpha(bits.ink, 0.5)
        }
        Row {
            visible: bits.part === "all" || bits.part === "right"
            x: bits.part === "all" ? bits.width - width - bits.u * 0.5 : (bits.width - width) / 2
            anchors.verticalCenter: parent.verticalCenter
            spacing: bits.u * 0.22
            Repeater { model: 3; Rectangle { width: bits.u * 0.3; height: width; radius: width / 2; color: Qt.alpha(bits.ink, 0.7) } }
        }
    }

    Repeater {
        model: [["island", "Island", "One pill hanging from the top"], ["fill", "Fill", "A bar along the top edge"],
                ["frame", "Frame", "The bar and a border round the screen"], ["solid", "Solid", "One floating bar"],
                ["modular", "Modular", "Each section on its own pill"]]
        Pressable {
            id: sc
            required property var modelData
            readonly property bool on: Theme.barStyle === modelData[0]
            readonly property string st: modelData[0]
            // all five on one row, as wide as the page lets them be
            width: Math.max(130, Math.floor((fl.width - 4 * fl.spacing) / 5)); height: 146
            radius: Theme.corner(80, 12)
            color: on ? Theme.accentContainer : (hovered ? Theme.containerHigh : Theme.container)
            border.width: on ? 2 : 1; border.color: on ? Theme.accent : Qt.alpha(Theme.text, 0.06)
            onClicked: Store.set("bar.style", modelData[0])
            // lifts a little under the pointer
            transform: Translate { y: sc.hovered && !sc.pressed ? -2 : 0; Behavior on y { NumberAnimation { duration: Theme.ms(160); easing.type: Easing.OutCubic } } }

            // a little screen
            ClippingRectangle {
                id: mini
                x: 10; y: 10; width: parent.width - 20; height: 78
                radius: Theme.corner(60, 8)
                color: Theme.m("surface_container_lowest", "#101014")
                readonly property color barC: Qt.alpha(Theme.frame, 1)
                Image {
                    anchors.fill: parent
                    source: fl.wall !== "" ? Wall.url(fl.wall) : ""
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: 320
                    asynchronous: true
                    opacity: 0.9
                }
                // a window
                Rectangle {
                    x: sc.st === "frame" ? 9 : 8
                    y: sc.st === "island" ? 18 : 22
                    width: parent.width - 2 * x; height: parent.height - y - (sc.st === "frame" ? 9 : 7)
                    radius: 4
                    color: Qt.alpha(Theme.m("surface_container_lowest", "#101014"), 0.85)
                    border.width: 1; border.color: Qt.alpha(Theme.text, 0.1)
                    Row { x: 5; y: 4; spacing: 2
                        Repeater { model: ["#ff6159", "#ffbd2e", "#28c941"]; Rectangle { required property string modelData; width: 4; height: 4; radius: 2; color: modelData; opacity: 0.8 } } }
                    Column { x: 6; y: 13; spacing: 4
                        Repeater { model: 3; Rectangle { required property int index; width: (index % 2 ? 0.45 : 0.65) * 120; height: 2.5; radius: 1.25; color: Qt.alpha(Theme.text, 0.15) } } }
                }
                // frame: the border round the screen
                Rectangle { visible: sc.st === "frame"; anchors.fill: parent; color: "transparent"; border.width: 4; border.color: mini.barC; radius: parent.radius }
                // island: a pill hanging from the top edge, with curved ears
                Rectangle {
                    visible: sc.st === "island"
                    anchors.horizontalCenter: parent.horizontalCenter; y: -7
                    width: 96; height: 20; radius: 10; color: mini.barC
                    Bits { x: 0; y: 7; width: parent.width; height: 11 }
                }
                // fill / frame: a bar along the top
                Rectangle {
                    visible: sc.st === "fill" || sc.st === "frame"
                    width: parent.width; height: 14; color: mini.barC
                    Bits { anchors.fill: parent; anchors.topMargin: 2; anchors.bottomMargin: 1 }
                }
                // solid: one floating bar
                Rectangle {
                    visible: sc.st === "solid"
                    x: 5; y: 5; width: parent.width - 10; height: 13; radius: 6.5; color: mini.barC
                    border.width: 1; border.color: Qt.alpha(Theme.text, 0.08)
                    Bits { anchors.fill: parent; anchors.margins: 1 }
                }
                // modular: each section on its own pill
                Repeater {
                    model: sc.st === "modular" ? [["left", 5, 38], ["middle", (mini.width - 30) / 2, 30], ["right", mini.width - 35, 30]] : []
                    Rectangle {
                        required property var modelData
                        x: modelData[1]; y: 5; width: modelData[2]; height: 13; radius: 6.5; color: mini.barC
                        border.width: 1; border.color: Qt.alpha(Theme.text, 0.08)
                        Bits { anchors.fill: parent; anchors.margins: 1; part: parent.modelData[0] }
                    }
                }
            }
            // the one in use: a tick
            Rectangle {
                visible: sc.on
                anchors.right: parent.right; anchors.top: parent.top; anchors.margins: 4
                width: 22; height: 22; radius: 11
                color: Theme.accent
                border.width: 2; border.color: Theme.accentContainer
                Icon { anchors.centerIn: parent; name: "check"; size: 14; color: Theme.onAccent }
            }
            Column {
                x: 12; y: mini.y + mini.height + 8; width: parent.width - 24
                spacing: 1
                Label { text: sc.modelData[1]; strong: true; font.pixelSize: Theme.sizeSmall + 1; color: sc.on ? Theme.onAccentContainer : Theme.text }
                Label { width: parent.width; text: sc.modelData[2]; muted: true; font.pixelSize: Theme.sizeSmall - 2; elide: Text.ElideRight }
            }
        }
    }
}
