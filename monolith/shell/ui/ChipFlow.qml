import QtQuick
import QtQuick.Layouts
import "../core"

// A longer choice (themes, layouts…): chips that wrap, the picked one filled. Options are
// strings, or [value, label] pairs.
Rectangle {
    id: cf
    property var opts: []
    property string value: ""
    signal picked(string v)
    Layout.fillWidth: true
    implicitHeight: flow.implicitHeight + 20
    radius: Theme.corner(56, 2)
    color: Theme.containerHigh
    Flow {
        id: flow
        x: 10; y: 10
        width: parent.width - 20
        spacing: 6
        Repeater {
            model: cf.opts
            Pressable {
                required property var modelData
                // (a [value, label] pair; lists from QML aren't always JS Arrays, so not Array.isArray)
                readonly property bool pair: typeof modelData === "object" && modelData !== null && modelData.length !== undefined
                readonly property string v: pair ? String(modelData[0]) : String(modelData)
                readonly property bool on: cf.value === v
                height: 32
                width: Math.min(cl.implicitWidth + 24, flow.width)
                color: on ? Theme.selected : Theme.control
                onClicked: cf.picked(v)
                Label { id: cl; anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 16); text: parent.pair ? parent.modelData[1] : parent.modelData; font.pixelSize: Theme.sizeSmall; strong: parent.on }
            }
        }
    }
}
