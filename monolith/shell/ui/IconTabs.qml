import QtQuick
import QtQuick.Layouts
import "../core"

// A page's tabs: [[value, label, icon], …] on a tonal bar, the picked one on a gliding pill.
Rectangle {
    id: seg
    property var opts: []
    property string value: ""
    signal picked(string v)
    Layout.fillWidth: true
    Layout.preferredHeight: 44
    radius: Theme.corner(height)
    color: Theme.container
    Rectangle {
        y: 4
        x: 4 + seg.opts.findIndex(o => o[0] === seg.value) * ((seg.width - 8) / seg.opts.length)
        width: (seg.width - 8) / seg.opts.length
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
                width: parent.width / seg.opts.length
                height: parent.height
                color: "transparent"
                onClicked: seg.picked(modelData[0])
                Row {
                    anchors.centerIn: parent
                    spacing: 6
                    Icon { name: modelData[2]; size: 18; filled: seg.value === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                    Label { text: modelData[1]; strong: seg.value === modelData[0]; anchors.verticalCenter: parent.verticalCenter }
                }
            }
        }
    }
}
