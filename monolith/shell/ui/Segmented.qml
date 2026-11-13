import QtQuick
import "../core"

// A segmented choice: options as [[value, label], …]; the picked one sits on a gliding pill.
SmoothRect {
    id: seg
    property var opts: []
    property string value: ""
    signal picked(string v)
    width: 220
    height: 40
    radius: Theme.corner(height)
    color: Theme.container
    border.width: Theme.outlineW
    border.color: Theme.outlineColor
    readonly property real cellW: (width - 8) / Math.max(1, opts.length)
    Rectangle {
        y: 4
        x: 4 + Math.max(0, seg.opts.findIndex(o => String(o[0]) === seg.value)) * seg.cellW
        visible: seg.opts.some(o => String(o[0]) === seg.value)
        width: seg.cellW
        height: seg.height - 8
        radius: Theme.corner(height)
        color: Theme.selected
        Behavior on x { NumberAnimation { duration: Theme.moveMs; easing.type: Easing.BezierSpline; easing.bezierCurve: Theme.standardCurve } }
    }
    Row {
        anchors.fill: parent
        anchors.margins: 4
        Repeater {
            model: seg.opts
            Pressable {
                required property var modelData
                width: seg.cellW
                height: parent.height
                color: "transparent"
                onClicked: seg.picked(String(modelData[0]))
                Label { anchors.centerIn: parent; width: Math.min(implicitWidth, parent.width - 8); horizontalAlignment: Text.AlignHCenter; text: modelData[1]; font.pixelSize: Theme.sizeSmall; strong: seg.value === String(modelData[0]) }
            }
        }
    }
}
